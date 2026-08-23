import pytest
from httpx import AsyncClient
from app.core.security import create_access_token
from app.models.enums import UserRole
from app.api.deps import get_current_active_admin
from app.core.errors import AppException, ErrorCode


@pytest.mark.asyncio
async def test_teacher_login_success(async_client: AsyncClient):
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "teacher1", "password": "teacher123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "access_token" in data["data"]
    assert "refresh_token" in data["data"]
    assert data["data"]["user"]["username"] == "teacher1"
    assert data["data"]["user"]["role"] == "TEACHER"
    assert data["data"]["user"]["teacher_id"] is not None


@pytest.mark.asyncio
async def test_admin_login_success(async_client: AsyncClient):
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": "admin123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["user"]["username"] == "admin"
    assert data["data"]["user"]["role"] == "ADMIN"


@pytest.mark.asyncio
async def test_login_invalid_password(async_client: AsyncClient):
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "teacher1", "password": "WrongPassword!"},
    )
    assert response.status_code == 400
    data = response.json()
    assert data["success"] is False
    assert data["code"] == "INVALID_CREDENTIALS"


@pytest.mark.asyncio
async def test_login_nonexistent_user(async_client: AsyncClient):
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "unknown_user_123", "password": "anypassword"},
    )
    assert response.status_code == 400
    data = response.json()
    assert data["success"] is False
    assert data["code"] == "INVALID_CREDENTIALS"


@pytest.mark.asyncio
async def test_token_refresh(async_client: AsyncClient):
    # 1. Login first
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "teacher1", "password": "teacher123"},
    )
    refresh_token = login_res.json()["data"]["refresh_token"]

    # 2. Refresh token
    refresh_res = await async_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 200
    data = refresh_res.json()
    assert data["success"] is True
    assert "access_token" in data["data"]
    assert "refresh_token" in data["data"]


@pytest.mark.asyncio
async def test_token_refresh_invalid(async_client: AsyncClient):
    response = await async_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "invalid.jwt.token"},
    )
    assert response.status_code == 401
    data = response.json()
    assert data["success"] is False


@pytest.mark.asyncio
async def test_get_me_authenticated(async_client: AsyncClient):
    # 1. Login
    login_res = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "teacher1", "password": "teacher123"},
    )
    access_token = login_res.json()["data"]["access_token"]

    # 2. Call /me with Bearer token
    response = await async_client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["data"]["username"] == "teacher1"
    assert data["data"]["role"] == "TEACHER"


@pytest.mark.asyncio
async def test_get_me_unauthorized(async_client: AsyncClient):
    response = await async_client.get("/api/v1/auth/me")
    assert response.status_code == 401
    data = response.json()
    assert data["success"] is False
    assert data["code"] == "UNAUTHORIZED"


@pytest.mark.asyncio
async def test_role_guard_rejects_teacher_from_admin_action():
    from app.models.user import User
    teacher_user = User(
        id="mock-teacher-id",
        username="teacher_mock",
        email="mock@school.edu.kg",
        hashed_password="mock",
        full_name="Mock Teacher",
        role=UserRole.TEACHER,
        is_active=True,
    )
    with pytest.raises(AppException) as exc_info:
        await get_current_active_admin(current_user=teacher_user)
    assert exc_info.value.code == ErrorCode.PERMISSION_DENIED
    assert exc_info.value.status_code == 403
