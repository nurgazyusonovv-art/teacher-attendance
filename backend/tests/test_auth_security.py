"""Phase 2 security cover: self-service password change, account-wide login
lockout, and encryption of stored secrets."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.config import settings
from app.core.crypto import decrypt_secret, encrypt_secret
from app.core.errors import AppException, ErrorCode
from app.models.auth_security import LoginAttempt
from app.schemas.auth import LoginRequest
from app.services.auth_service import AuthService


async def _register_teacher(
    async_client: AsyncClient, admin_auth_headers: dict, password: str
) -> str:
    uid = uuid.uuid4().hex[:6]
    username = f"pwd_{uid}"
    response = await async_client.post(
        "/api/v1/teachers",
        json={
            "full_name": "Сырсөз Тести",
            "username": username,
            "password": password,
            "employee_code": f"PWD-{uid}",
        },
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    return username


async def _login(async_client: AsyncClient, username: str, password: str):
    return await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": username, "password": password},
    )


# --- Self-service password change --------------------------------------------


@pytest.mark.asyncio
async def test_teacher_can_change_own_password(
    async_client: AsyncClient, admin_auth_headers: dict
):
    old_password = "oldpassword123"
    new_password = "newpassword456"
    username = await _register_teacher(
        async_client, admin_auth_headers, old_password
    )

    login = await _login(async_client, username, old_password)
    headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

    changed = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": old_password, "new_password": new_password},
        headers=headers,
    )
    assert changed.status_code == 200
    assert changed.json()["success"] is True

    assert (await _login(async_client, username, old_password)).status_code == 400
    assert (await _login(async_client, username, new_password)).status_code == 200


@pytest.mark.asyncio
async def test_change_password_rejects_wrong_or_identical_password(
    async_client: AsyncClient, admin_auth_headers: dict
):
    password = "somepassword123"
    username = await _register_teacher(async_client, admin_auth_headers, password)
    login = await _login(async_client, username, password)
    headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

    wrong = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "not-the-password", "new_password": "another123"},
        headers=headers,
    )
    assert wrong.status_code == 400
    assert wrong.json()["code"] == ErrorCode.INVALID_CREDENTIALS.value

    identical = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": password, "new_password": password},
        headers=headers,
    )
    assert identical.status_code == 400
    assert identical.json()["code"] == ErrorCode.VALIDATION_ERROR.value

    # The password still works, so neither rejection changed anything.
    assert (await _login(async_client, username, password)).status_code == 200


@pytest.mark.asyncio
async def test_change_password_revokes_other_sessions(
    async_client: AsyncClient, admin_auth_headers: dict
):
    password = "sessionpass123"
    username = await _register_teacher(async_client, admin_auth_headers, password)

    other_device = await _login(async_client, username, password)
    other_headers = {
        "Authorization": f"Bearer {other_device.json()['data']['access_token']}"
    }
    this_device = await _login(async_client, username, password)
    this_headers = {
        "Authorization": f"Bearer {this_device.json()['data']['access_token']}"
    }

    assert (await async_client.get("/api/v1/auth/me", headers=other_headers)).status_code == 200

    changed = await async_client.post(
        "/api/v1/auth/change-password",
        json={"current_password": password, "new_password": "brandnew456"},
        headers=this_headers,
    )
    assert changed.status_code == 200

    # The other device is signed out, the changing device keeps working.
    assert (await async_client.get("/api/v1/auth/me", headers=other_headers)).status_code == 401
    assert (await async_client.get("/api/v1/auth/me", headers=this_headers)).status_code == 200


# --- Account-wide login lockout ----------------------------------------------


@pytest.mark.asyncio
async def test_lockout_counts_failures_across_source_ips(
    db_session, admin_auth_headers: dict, async_client: AsyncClient, monkeypatch
):
    """Per-IP lockout alone lets an attacker keep guessing by rotating IPs."""
    password = "lockoutpass123"
    username = await _register_teacher(async_client, admin_auth_headers, password)
    monkeypatch.setattr(settings, "LOGIN_MAX_FAILED_ATTEMPTS_PER_IDENTIFIER", 3)

    wrong = LoginRequest(username_or_email=username, password="wrong-password")
    for index in range(3):
        with pytest.raises(AppException) as failure:
            await AuthService.authenticate_user(
                db_session, wrong, client_ip=f"10.0.0.{index}"
            )
        # Each IP stays well under its own limit.
        assert failure.value.code == ErrorCode.INVALID_CREDENTIALS

    # A fresh IP is now blocked, and so is the correct password.
    with pytest.raises(AppException) as blocked:
        await AuthService.authenticate_user(
            db_session, wrong, client_ip="10.0.0.99"
        )
    assert blocked.value.code == ErrorCode.RATE_LIMITED

    with pytest.raises(AppException) as blocked_valid:
        await AuthService.authenticate_user(
            db_session,
            LoginRequest(username_or_email=username, password=password),
            client_ip="10.0.0.100",
        )
    assert blocked_valid.value.code == ErrorCode.RATE_LIMITED


@pytest.mark.asyncio
async def test_successful_login_clears_failures_from_every_ip(
    db_session, admin_auth_headers: dict, async_client: AsyncClient, monkeypatch
):
    password = "clearpass123"
    username = await _register_teacher(async_client, admin_auth_headers, password)
    monkeypatch.setattr(settings, "LOGIN_MAX_FAILED_ATTEMPTS_PER_IDENTIFIER", 5)

    wrong = LoginRequest(username_or_email=username, password="wrong-password")
    for index in range(2):
        with pytest.raises(AppException):
            await AuthService.authenticate_user(
                db_session, wrong, client_ip=f"192.168.1.{index}"
            )

    identifier_hash = AuthService._login_key(username)
    remaining = (
        await db_session.execute(
            select(LoginAttempt).where(
                LoginAttempt.identifier_hash == identifier_hash
            )
        )
    ).scalars().all()
    assert len(remaining) == 2

    await AuthService.authenticate_user(
        db_session,
        LoginRequest(username_or_email=username, password=password),
        client_ip="192.168.1.50",
    )

    cleared = (
        await db_session.execute(
            select(LoginAttempt).where(
                LoginAttempt.identifier_hash == identifier_hash
            )
        )
    ).scalars().all()
    assert cleared == []


# --- Secret encryption --------------------------------------------------------


def test_secret_roundtrip_and_legacy_plaintext():
    secret = "123456:AAbbCcDdEeFf-telegram-bot-token"
    stored = encrypt_secret(secret)

    assert stored is not None
    assert secret not in stored  # not readable from a database dump
    assert decrypt_secret(stored) == secret

    # Already-encrypted values are not double wrapped.
    assert encrypt_secret(stored) == stored

    # Values written before encryption existed stay usable.
    assert decrypt_secret(secret) == secret

    assert encrypt_secret(None) is None
    assert encrypt_secret("   ") is None
    assert decrypt_secret(None) is None


def test_secret_is_unreadable_after_key_change(monkeypatch):
    stored = encrypt_secret("bot-token-value")
    monkeypatch.setattr(settings, "SECRETS_ENCRYPTION_KEY", "a-different-key-entirely")
    # Degrades to "not configured" instead of raising, so an admin can re-enter it.
    assert decrypt_secret(stored) is None


@pytest.mark.asyncio
async def test_school_update_stores_bot_token_encrypted(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    from app.models.school import School

    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    token = "987654:ZZyyXXwwVv-secret"

    response = await async_client.patch(
        f"/api/v1/schools/{school.id}",
        json={"telegram_bot_token": token},
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    # Never serialized back to any client.
    assert "telegram_bot_token" not in response.json()

    await db_session.refresh(school)
    assert school.telegram_bot_token != token
    assert school.telegram_bot_token.startswith("enc:v1:")
    assert decrypt_secret(school.telegram_bot_token) == token
