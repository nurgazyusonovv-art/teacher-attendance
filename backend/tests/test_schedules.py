from datetime import date
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_weekly_schedules(
    async_client: AsyncClient, admin_auth_headers: dict
):
    response = await async_client.get(
        "/api/v1/schedules", headers=admin_auth_headers
    )
    assert response.status_code == 200
    data = response.json()
    assert "schedules" in data
    assert len(data["schedules"]) >= 5


@pytest.mark.asyncio
async def test_create_and_update_schedule(
    async_client: AsyncClient, admin_auth_headers: dict
):
    curr_school = await async_client.get(
        "/api/v1/schools/current", headers=admin_auth_headers
    )
    school_id = curr_school.json()["id"]

    # Create Saturday schedule (day 5)
    sat_payload = {
        "school_id": school_id,
        "day_of_week": 5,
        "start_time": "08:30:00",
        "end_time": "14:00:00",
        "grace_minutes": 5,
        "is_day_off": False,
    }
    create_res = await async_client.post(
        "/api/v1/schedules", json=sat_payload, headers=admin_auth_headers
    )
    assert create_res.status_code == 200
    sched = create_res.json()
    assert sched["day_of_week"] == 5
    assert sched["start_time"] == "08:30:00"
    schedule_id = sched["id"]

    # Update end_time
    patch_res = await async_client.patch(
        f"/api/v1/schedules/{schedule_id}",
        json={"end_time": "15:00:00"},
        headers=admin_auth_headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["end_time"] == "15:00:00"


@pytest.mark.asyncio
async def test_resolve_schedule_business_logic(db_session):
    from app.services.schedule_service import ScheduleService
    from app.models.school import School
    from sqlalchemy import select

    res = await db_session.execute(select(School).limit(1))
    school = res.scalar_one()

    # Monday (2026-08-24 is Monday)
    monday_date = date(2026, 8, 24)
    sched = await ScheduleService.resolve_schedule_for_date(
        db_session, school.id, None, monday_date
    )
    assert sched is not None
    assert sched.day_of_week == 0
    assert sched.is_day_off is False

    # Sunday (2026-08-30 is Sunday)
    sunday_date = date(2026, 8, 30)
    sun_sched = await ScheduleService.resolve_schedule_for_date(
        db_session, school.id, None, sunday_date
    )
    assert sun_sched is None or sun_sched.is_day_off is True


@pytest.mark.asyncio
async def test_teacher_inherits_school_schedule(db_session):
    from app.services.schedule_service import ScheduleService
    from app.models.school import School
    from sqlalchemy import select

    res = await db_session.execute(select(School).limit(1))
    school = res.scalar_one()

    # Get schedules for a teacher without custom schedules
    schedules = await ScheduleService.get_schedules_for_school(
        db_session, school.id, teacher_id="fake-teacher-uuid"
    )
    # Should automatically inherit the school's default schedules
    assert len(schedules) >= 5
    for s in schedules:
        assert s.school_id == school.id

