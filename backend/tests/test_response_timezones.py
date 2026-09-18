"""Attendance responses carry the school's wall clock, not UTC.

The columns are TIMESTAMPTZ, so a value written as 14:57+06:00 reads back from
PostgreSQL as 08:57+00:00. Serialized unchanged it reaches clients as `...Z`,
and a client that renders the time it was sent shows the wrong hour — which is
exactly what happened once the mobile app stopped applying its own offset.
"""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher

BISHKEK = ZoneInfo("Asia/Bishkek")


def _assert_school_local(raw: str, expected_wall_clock: str) -> None:
    """The serialized value must read as the school's wall clock."""
    assert raw is not None
    assert not raw.endswith("Z"), f"{raw} is UTC, not school-local"
    parsed = datetime.fromisoformat(raw)
    assert parsed.utcoffset() is not None, f"{raw} has no offset"
    assert parsed.strftime("%H:%M") == expected_wall_clock, raw


@pytest.fixture
async def _recorded_day(db_session):
    """A stored attendance day, written the way the service writes one."""
    teacher = (
        await db_session.execute(
            select(Teacher).join(Teacher.user).limit(1)
        )
    ).scalars().first()
    school = (
        await db_session.execute(
            select(School).where(School.id == teacher.school_id)
        )
    ).scalar_one()

    day = datetime(2026, 9, 14, 14, 57, tzinfo=BISHKEK)
    record = DailyAttendance(
        teacher_id=teacher.id,
        school_id=school.id,
        date=day.date(),
        check_in_time=day,
        check_out_time=datetime(2026, 9, 14, 18, 5, tzinfo=BISHKEK),
        status=AttendanceStatus.ON_TIME,
        late_minutes=0,
        worked_minutes=188,
    )
    db_session.add(record)
    await db_session.commit()
    yield teacher, record
    await db_session.delete(record)
    await db_session.commit()


@pytest.mark.asyncio
async def test_a_utc_timestamp_is_returned_in_school_time(
    async_client: AsyncClient, admin_auth_headers: dict, _recorded_day
):
    teacher, _ = _recorded_day

    response = await async_client.get(
        f"/api/v1/attendance/teacher/{teacher.id}/history",
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    row = next(r for r in response.json() if r["date"] == "2026-09-14")

    _assert_school_local(row["check_in_time"], "14:57")
    _assert_school_local(row["check_out_time"], "18:05")


@pytest.mark.asyncio
async def test_the_stored_instant_is_unchanged(
    async_client: AsyncClient, admin_auth_headers: dict, _recorded_day
):
    """Localizing is a presentation concern; it must not move the instant."""
    teacher, _ = _recorded_day

    response = await async_client.get(
        f"/api/v1/attendance/teacher/{teacher.id}/history",
        headers=admin_auth_headers,
    )
    row = next(r for r in response.json() if r["date"] == "2026-09-14")

    parsed = datetime.fromisoformat(row["check_in_time"]).astimezone(timezone.utc)
    assert parsed == datetime(2026, 9, 14, 8, 57, tzinfo=timezone.utc)


@pytest.mark.asyncio
async def test_school_history_is_localized_too(
    async_client: AsyncClient, admin_auth_headers: dict, _recorded_day
):
    response = await async_client.get(
        "/api/v1/attendance/history?start_date=2026-09-14&end_date=2026-09-14",
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert items, "the seeded day should be in the school-wide history"
    _assert_school_local(items[0]["check_in_time"], "14:57")


@pytest.mark.asyncio
async def test_dashboard_is_localized_too(
    async_client: AsyncClient, admin_auth_headers: dict, _recorded_day
):
    response = await async_client.get(
        "/api/v1/attendance/dashboard/today?target_date=2026-09-14",
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    rows = [
        r for r in response.json()["records"] if r["check_in_time"] is not None
    ]
    assert rows, "the seeded day should appear on the dashboard"
    _assert_school_local(rows[0]["check_in_time"], "14:57")


@pytest.mark.asyncio
async def test_today_status_is_localized_too(
    async_client: AsyncClient, teacher_auth_headers: dict, db_session
):
    teacher = (
        await db_session.execute(
            select(Teacher).join(Teacher.user).limit(1)
        )
    ).scalars().first()
    school = (
        await db_session.execute(
            select(School).where(School.id == teacher.school_id)
        )
    ).scalar_one()
    today = datetime.now(ZoneInfo(school.timezone)).date()

    existing = (
        await db_session.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher.id,
                DailyAttendance.date == today,
            )
        )
    ).scalar_one_or_none()
    if existing is None:
        existing = DailyAttendance(
            teacher_id=teacher.id,
            school_id=school.id,
            date=today,
            status=AttendanceStatus.ON_TIME,
            late_minutes=0,
            worked_minutes=0,
        )
        db_session.add(existing)
    existing.check_in_time = datetime.combine(
        today, datetime.min.time(), tzinfo=BISHKEK
    ).replace(hour=14, minute=57)
    await db_session.commit()

    response = await async_client.get(
        "/api/v1/attendance/today", headers=teacher_auth_headers
    )
    assert response.status_code == 200
    body = response.json()
    _assert_school_local(body["check_in_time"], "14:57")
    assert body["utc_offset_minutes"] == 360

    await db_session.delete(existing)
    await db_session.commit()
