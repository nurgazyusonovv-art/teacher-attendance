import pytest
from datetime import time
from httpx import AsyncClient
from app.models.school import School
from app.models.audit import AuditLog
from app.models.enums import UserRole
from app.models.teacher import Teacher
from app.models.user import User
from app.core.security import get_password_hash
from sqlalchemy import select


@pytest.mark.asyncio
async def test_get_current_school(async_client: AsyncClient, admin_auth_headers: dict):
    response = await async_client.get(
        "/api/v1/schools/current", headers=admin_auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "№1 Орто Мектеп"
    assert data["allowed_radius_meters"] > 0
    assert data["timezone"] == "Asia/Bishkek"
    assert "telegram_bot_token" not in data


@pytest.mark.asyncio
async def test_update_school_settings_by_admin(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    # First get school ID
    curr_res = await async_client.get(
        "/api/v1/schools/current", headers=admin_auth_headers
    )
    school_id = curr_res.json()["id"]

    # Update radius to 120m and grace period to 10 min
    update_payload = {
        "allowed_radius_meters": 120.0,
        "grace_minutes": 10,
        "max_accuracy_meters": 45.0,
    }
    res = await async_client.patch(
        f"/api/v1/schools/{school_id}",
        json=update_payload,
        headers=admin_auth_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["allowed_radius_meters"] == 120.0
    assert data["grace_minutes"] == 10
    assert data["max_accuracy_meters"] == 45.0
    audit_result = await db_session.execute(
        select(AuditLog).where(
            AuditLog.action == "SCHOOL_SETTINGS_UPDATED",
            AuditLog.entity_id == school_id,
        )
    )
    assert audit_result.scalars().first() is not None


@pytest.mark.asyncio
async def test_teacher_cannot_update_school_settings(
    async_client: AsyncClient, teacher_auth_headers: dict
):
    curr_res = await async_client.get(
        "/api/v1/schools/current", headers=teacher_auth_headers
    )
    school_id = curr_res.json()["id"]

    update_payload = {"allowed_radius_meters": 300.0}
    res = await async_client.patch(
        f"/api/v1/schools/{school_id}",
        json=update_payload,
        headers=teacher_auth_headers,
    )
    assert res.status_code == 403
    assert res.json()["code"] == "PERMISSION_DENIED"


@pytest.mark.asyncio
async def test_admin_cannot_access_another_school(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    other_school = School(
        name="Other School",
        code="OTHER-001",
        latitude=42.9,
        longitude=74.6,
        allowed_radius_meters=80,
        max_accuracy_meters=50,
        default_start_time=time(8),
        default_end_time=time(17),
        grace_minutes=5,
        timezone="Asia/Bishkek",
    )
    db_session.add(other_school)
    await db_session.flush()
    other_user = User(
        username="other-school-teacher",
        email="other-school-teacher@example.com",
        full_name="Other School Teacher",
        hashed_password=get_password_hash("unused-test-password"),
        role=UserRole.TEACHER,
        school_id=other_school.id,
    )
    db_session.add(other_user)
    await db_session.flush()
    other_teacher = Teacher(
        user_id=other_user.id,
        school_id=other_school.id,
        employee_code="OTHER-SCHOOL-001",
    )
    db_session.add(other_teacher)
    await db_session.commit()
    await db_session.refresh(other_school)

    read_response = await async_client.get(
        f"/api/v1/schools/{other_school.id}", headers=admin_auth_headers
    )
    update_response = await async_client.patch(
        f"/api/v1/schools/{other_school.id}",
        json={"allowed_radius_meters": 300},
        headers=admin_auth_headers,
    )
    qr_response = await async_client.get(
        f"/api/v1/qr/{other_school.id}", headers=admin_auth_headers
    )
    history_response = await async_client.get(
        f"/api/v1/attendance/teacher/{other_teacher.id}/history",
        headers=admin_auth_headers,
    )

    assert read_response.status_code == 403
    assert update_response.status_code == 403
    assert qr_response.status_code == 403
    assert history_response.status_code == 403
