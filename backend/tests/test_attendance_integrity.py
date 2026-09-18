"""Regression cover for the Phase 0/1 integrity fixes.

- a hard delete may not silently destroy attendance history
- the absence epoch is a per-school setting, not a constant in the code
- check-out runs through the same geofence gate as check-in
"""

import uuid
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.errors import AppException, ErrorCode
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.services.absence_service import AbsenceService
from app.services.geofence_service import GeofenceService
from app.services.qr_service import QrService

from tests.test_attendance import create_fresh_teacher


# --- Hard delete guard -------------------------------------------------------


async def _create_teacher(async_client: AsyncClient, headers: dict) -> dict:
    uid = uuid.uuid4().hex[:6]
    response = await async_client.post(
        "/api/v1/teachers",
        json={
            "full_name": "Өчүрүлүүчү Мугалим",
            "username": f"deletable_{uid}",
            "password": "password123",
            "employee_code": f"DEL-{uid}",
        },
        headers=headers,
    )
    assert response.status_code == 200
    return response.json()


@pytest.mark.asyncio
async def test_hard_delete_without_history_still_works(
    async_client: AsyncClient, admin_auth_headers: dict
):
    teacher = await _create_teacher(async_client, admin_auth_headers)
    response = await async_client.delete(
        f"/api/v1/teachers/{teacher['id']}?hard_delete=true",
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["success"] is True


@pytest.mark.asyncio
async def test_hard_delete_refuses_to_destroy_attendance_history(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    teacher = await _create_teacher(async_client, admin_auth_headers)
    db_session.add(
        DailyAttendance(
            teacher_id=teacher["id"],
            school_id=teacher["school_id"],
            date=date(2026, 9, 15),
            status=AttendanceStatus.ON_TIME,
            late_minutes=0,
            worked_minutes=480,
        )
    )
    await db_session.commit()

    blocked = await async_client.delete(
        f"/api/v1/teachers/{teacher['id']}?hard_delete=true",
        headers=admin_auth_headers,
    )
    assert blocked.status_code == 409
    assert blocked.json()["code"] == ErrorCode.VALIDATION_ERROR.value
    assert blocked.json()["details"]["total"] == 1

    # The record survived the refused delete.
    surviving = (
        await db_session.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher["id"]
            )
        )
    ).scalars().all()
    assert len(surviving) == 1

    confirmed = await async_client.delete(
        f"/api/v1/teachers/{teacher['id']}"
        "?hard_delete=true&confirmation=DELETE%20ATTENDANCE%20HISTORY",
        headers=admin_auth_headers,
    )
    assert confirmed.status_code == 200


# --- Per-school absence start date -------------------------------------------


@pytest.mark.asyncio
async def test_absence_start_date_is_per_school(db_session, monkeypatch):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    original_start = school.attendance_start_date
    day = date(2026, 9, 10)  # Thursday

    # Teachers created during the test run predate nothing; age them so the
    # per-teacher onboarding guard is not what decides this assertion.
    teachers = (await db_session.execute(select(Teacher))).scalars().all()
    for teacher in teachers:
        teacher.created_at = datetime(2026, 9, 1, tzinfo=ZoneInfo("Asia/Bishkek"))
    await db_session.commit()

    monkeypatch.setattr(
        "app.services.absence_service.current_time_in_school_timezone",
        lambda _: datetime(2026, 9, 10, 18, tzinfo=ZoneInfo("Asia/Bishkek")),
    )

    # A school that starts accounting after the evaluated day is skipped.
    school.attendance_start_date = day + timedelta(days=1)
    await db_session.commit()
    assert await AbsenceService.process_daily_absences(db_session, school.id, day) == []

    # Moving the setting back makes the very same day eligible again.
    school.attendance_start_date = day
    await db_session.commit()
    assert await AbsenceService.process_daily_absences(db_session, school.id, day) != []

    school.attendance_start_date = original_start
    await db_session.commit()


@pytest.mark.asyncio
async def test_absence_start_date_falls_back_to_school_creation(db_session):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    original_start = school.attendance_start_date
    school.attendance_start_date = None
    school.created_at = datetime(2026, 9, 12, tzinfo=ZoneInfo("Asia/Bishkek"))
    await db_session.commit()

    assert AbsenceService.resolve_start_date(school) == date(2026, 9, 12)

    school.attendance_start_date = original_start
    await db_session.commit()


# --- Shared geofence gate ----------------------------------------------------


def _scan(school: School, *, lat: float, lon: float, accuracy: float) -> float:
    return GeofenceService.verify_or_raise(
        teacher_lat=lat,
        teacher_lon=lon,
        teacher_accuracy=accuracy,
        school_lat=school.latitude,
        school_lon=school.longitude,
        allowed_radius_meters=school.allowed_radius_meters,
        max_accuracy_meters=school.max_accuracy_meters,
    )


@pytest.mark.asyncio
async def test_geofence_gate_rejects_and_accepts(db_session):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()

    assert _scan(school, lat=school.latitude, lon=school.longitude, accuracy=10.0) == 0.0

    with pytest.raises(AppException) as too_far:
        _scan(school, lat=school.latitude + 0.05, lon=school.longitude, accuracy=10.0)
    assert too_far.value.code == ErrorCode.LOCATION_OUTSIDE_SCHOOL

    with pytest.raises(AppException) as too_coarse:
        _scan(school, lat=school.latitude, lon=school.longitude, accuracy=500.0)
    assert too_coarse.value.code == ErrorCode.LOCATION_ACCURACY_TOO_LOW


@pytest.mark.asyncio
async def test_check_out_enforces_geofence(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    """Check-out used to carry its own copy of the geofence checks.

    The geofence must reject before any check-in state is even consulted.
    """
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    qr_info = await QrService.get_active_school_qr(db_session, school.id)
    teacher_headers = await create_fresh_teacher(async_client, admin_auth_headers)

    outside = await async_client.post(
        "/api/v1/attendance/check-out",
        json={
            "school_id": school.id,
            "qr_token": qr_info.qr_token,
            "latitude": school.latitude + 0.05,
            "longitude": school.longitude,
            "accuracy": 10.0,
        },
        headers=teacher_headers,
    )
    assert outside.status_code == 400
    assert outside.json()["code"] == ErrorCode.LOCATION_OUTSIDE_SCHOOL.value

    too_coarse = await async_client.post(
        "/api/v1/attendance/check-out",
        json={
            "school_id": school.id,
            "qr_token": qr_info.qr_token,
            "latitude": school.latitude,
            "longitude": school.longitude,
            "accuracy": school.max_accuracy_meters + 1,
        },
        headers=teacher_headers,
    )
    assert too_coarse.status_code == 400
    assert too_coarse.json()["code"] == ErrorCode.LOCATION_ACCURACY_TOO_LOW.value
