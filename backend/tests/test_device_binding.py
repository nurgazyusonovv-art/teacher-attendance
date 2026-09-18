"""One teacher, one approved device (PROJECT.md §10).

The first device registers as approved, a second one waits for an
administrator, and an attendance scan from an unapproved device is rejected —
but only for schools that switched enforcement on.
"""

import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.errors import ErrorCode
from app.models.school import School
from app.services.qr_service import QrService

from tests.test_attendance import create_fresh_teacher


async def _register_device(
    async_client: AsyncClient, headers: dict, device_id: str
) -> dict:
    response = await async_client.post(
        "/api/v1/devices/register",
        json={"device_id": device_id, "platform": "ANDROID"},
        headers=headers,
    )
    assert response.status_code == 200
    return response.json()


async def _set_binding(
    async_client: AsyncClient, admin_headers: dict, school_id: str, enabled: bool
) -> None:
    response = await async_client.patch(
        f"/api/v1/schools/{school_id}",
        json={"device_binding_enabled": enabled},
        headers=admin_headers,
    )
    assert response.status_code == 200
    assert response.json()["device_binding_enabled"] is enabled


@pytest.fixture
async def _binding_off(async_client: AsyncClient, admin_auth_headers: dict, db_session):
    """Leaves the shared school switch off for every other test."""
    yield
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    await _set_binding(async_client, admin_auth_headers, school.id, False)


# --- Registration lifecycle ---------------------------------------------------


@pytest.mark.asyncio
async def test_first_device_is_approved_second_waits_for_admin(
    async_client: AsyncClient, admin_auth_headers: dict
):
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)
    uid = uuid.uuid4().hex[:8]

    first = await _register_device(async_client, teacher_headers, f"phone-a-{uid}")
    assert first["status"] == "APPROVED"
    assert first["is_active"] is True
    assert first["approved_at"] is not None

    second = await _register_device(async_client, teacher_headers, f"phone-b-{uid}")
    assert second["status"] == "PENDING"
    assert second["is_active"] is False

    mine = await async_client.get("/api/v1/devices/me", headers=teacher_headers)
    assert mine.status_code == 200
    assert {d["status"] for d in mine.json()} == {"APPROVED", "PENDING"}


@pytest.mark.asyncio
async def test_approving_a_device_revokes_the_previous_one(
    async_client: AsyncClient, admin_auth_headers: dict
):
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)
    uid = uuid.uuid4().hex[:8]
    old_device = await _register_device(async_client, teacher_headers, f"old-{uid}")
    new_device = await _register_device(async_client, teacher_headers, f"new-{uid}")

    approved = await async_client.post(
        f"/api/v1/devices/{new_device['id']}/approve", headers=admin_auth_headers
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "APPROVED"

    mine = await async_client.get("/api/v1/devices/me", headers=teacher_headers)
    by_id = {d["id"]: d for d in mine.json()}
    assert by_id[new_device["id"]]["status"] == "APPROVED"
    assert by_id[old_device["id"]]["status"] == "REVOKED"


@pytest.mark.asyncio
async def test_revoked_device_is_not_resurrected_by_reregistering(
    async_client: AsyncClient, admin_auth_headers: dict
):
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)
    uid = uuid.uuid4().hex[:8]
    device = await _register_device(async_client, teacher_headers, f"lost-{uid}")

    revoked = await async_client.post(
        f"/api/v1/devices/{device['id']}/revoke", headers=admin_auth_headers
    )
    assert revoked.status_code == 200
    assert revoked.json()["status"] == "REVOKED"

    again = await _register_device(async_client, teacher_headers, f"lost-{uid}")
    assert again["status"] == "REVOKED"


@pytest.mark.asyncio
async def test_admin_device_queue_is_school_scoped(
    async_client: AsyncClient, admin_auth_headers: dict, teacher_auth_headers: dict
):
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)
    uid = uuid.uuid4().hex[:8]
    await _register_device(async_client, teacher_headers, f"first-{uid}")
    await _register_device(async_client, teacher_headers, f"second-{uid}")

    pending = await async_client.get(
        "/api/v1/devices?status=PENDING", headers=admin_auth_headers
    )
    assert pending.status_code == 200
    rows = pending.json()
    assert any(d["device_id"] == f"second-{uid}" for d in rows)
    assert all(d["status"] == "PENDING" for d in rows)
    assert all(d["teacher_name"] for d in rows)

    # A teacher may not read the school-wide queue.
    forbidden = await async_client.get("/api/v1/devices", headers=teacher_headers)
    assert forbidden.status_code == 403


# --- Attendance enforcement ---------------------------------------------------


@pytest.mark.asyncio
async def test_scan_from_unapproved_device_is_rejected_when_binding_is_on(
    async_client: AsyncClient, admin_auth_headers: dict, db_session, monkeypatch,
    _binding_off,
):
    monkeypatch.setattr(
        "app.services.attendance_service.current_time_in_school_timezone",
        lambda _timezone: datetime(2026, 9, 7, 8, 0, tzinfo=ZoneInfo("Asia/Bishkek")),
    )
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)
    uid = uuid.uuid4().hex[:8]

    approved = await _register_device(async_client, teacher_headers, f"bound-{uid}")
    pending = await _register_device(async_client, teacher_headers, f"rogue-{uid}")
    assert approved["status"] == "APPROVED"
    assert pending["status"] == "PENDING"

    await _set_binding(async_client, admin_auth_headers, school.id, True)

    def scan(device_id=None):
        body = {
            "school_id": school.id,
            "qr_token": qr_info.qr_token,
            "latitude": school.latitude,
            "longitude": school.longitude,
            "accuracy": 10.0,
        }
        if device_id:
            body["device_id"] = device_id
        return body

    rogue = await async_client.post(
        "/api/v1/attendance/check-in", json=scan(f"rogue-{uid}"), headers=teacher_headers
    )
    assert rogue.status_code == 403
    assert rogue.json()["code"] == ErrorCode.DEVICE_NOT_APPROVED.value

    # An app version that sends no device id at all cannot slip past the gate.
    missing = await async_client.post(
        "/api/v1/attendance/check-in", json=scan(), headers=teacher_headers
    )
    assert missing.status_code == 400
    assert missing.json()["code"] == ErrorCode.DEVICE_REQUIRED.value

    ok = await async_client.post(
        "/api/v1/attendance/check-in", json=scan(f"bound-{uid}"), headers=teacher_headers
    )
    assert ok.status_code == 200
    assert ok.json()["check_in_time"] is not None


@pytest.mark.asyncio
async def test_binding_off_keeps_deployed_app_versions_working(
    async_client: AsyncClient, admin_auth_headers: dict, db_session, monkeypatch
):
    """Enforcement is opt-in; without it a scan with no device id still works."""
    monkeypatch.setattr(
        "app.services.attendance_service.current_time_in_school_timezone",
        lambda _timezone: datetime(2026, 9, 7, 8, 0, tzinfo=ZoneInfo("Asia/Bishkek")),
    )
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    assert school.device_binding_enabled is False
    qr_info = await QrService.get_active_school_qr(db_session, school.id)
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    response = await async_client.post(
        "/api/v1/attendance/check-in",
        json={
            "school_id": school.id,
            "qr_token": qr_info.qr_token,
            "latitude": school.latitude,
            "longitude": school.longitude,
            "accuracy": 10.0,
        },
        headers=teacher_headers,
    )
    assert response.status_code == 200
