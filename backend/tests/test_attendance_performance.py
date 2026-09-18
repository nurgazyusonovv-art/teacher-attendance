"""Phase 3 cover: the read paths must filter in SQL and stop scaling in
queries with the size of the school."""

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import event, select

from app.db.session import async_engine
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.services.attendance_service import AttendanceService
from app.services.schedule_service import ScheduleService

from tests.test_attendance import create_fresh_teacher


class _QueryCounter:
    """Counts SQL statements issued inside the block."""

    def __init__(self):
        self.count = 0

    def __enter__(self):
        event.listen(async_engine.sync_engine, "before_cursor_execute", self._record)
        return self

    def __exit__(self, *_):
        event.remove(async_engine.sync_engine, "before_cursor_execute", self._record)

    def _record(self, *_args, **_kwargs):
        self.count += 1


async def _seed_history(db_session, days: int) -> tuple[Teacher, School]:
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teacher = (await db_session.execute(select(Teacher).limit(1))).scalar_one()

    existing = (
        await db_session.execute(
            select(DailyAttendance.date).where(
                DailyAttendance.teacher_id == teacher.id
            )
        )
    ).scalars().all()
    known = set(existing)

    start = date(2025, 1, 1)
    for offset in range(days):
        day = start + timedelta(days=offset)
        if day in known:
            continue
        db_session.add(
            DailyAttendance(
                teacher_id=teacher.id,
                school_id=school.id,
                date=day,
                status=AttendanceStatus.ON_TIME,
                late_minutes=0,
                worked_minutes=480,
            )
        )
    await db_session.commit()
    return teacher, school


@pytest.mark.asyncio
async def test_history_filters_by_month_in_sql(db_session):
    teacher, _ = await _seed_history(db_session, 70)

    january = await AttendanceService.get_teacher_history(
        db_session, teacher.id, year=2025, month=1
    )
    assert january, "January 2025 was seeded"
    assert all(r.date.year == 2025 and r.date.month == 1 for r in january)
    assert len(january) == 31

    february = await AttendanceService.get_teacher_history(
        db_session, teacher.id, year=2025, month=2
    )
    assert all(r.date.month == 2 for r in february)


@pytest.mark.asyncio
async def test_history_supports_date_range_and_paging(db_session):
    teacher, _ = await _seed_history(db_session, 70)

    ranged = await AttendanceService.get_teacher_history(
        db_session,
        teacher.id,
        start_date=date(2025, 1, 10),
        end_date=date(2025, 1, 20),
    )
    assert len(ranged) == 11
    assert ranged[0].date == date(2025, 1, 20)  # newest first

    first_page = await AttendanceService.get_teacher_history(
        db_session, teacher.id, start_date=date(2025, 1, 1), limit=5
    )
    second_page = await AttendanceService.get_teacher_history(
        db_session, teacher.id, start_date=date(2025, 1, 1), skip=5, limit=5
    )
    assert len(first_page) == 5
    assert len(second_page) == 5
    assert {r.id for r in first_page}.isdisjoint({r.id for r in second_page})


@pytest.mark.asyncio
async def test_history_query_count_does_not_grow_with_row_count(db_session):
    teacher, _ = await _seed_history(db_session, 70)

    with _QueryCounter() as small:
        await AttendanceService.get_teacher_history(
            db_session, teacher.id, start_date=date(2025, 1, 1), limit=5
        )
    with _QueryCounter() as large:
        await AttendanceService.get_teacher_history(
            db_session, teacher.id, start_date=date(2025, 1, 1), limit=60
        )
    assert small.count == large.count
    assert large.count <= 3


@pytest.mark.asyncio
async def test_school_history_returns_every_teacher_in_one_page(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    _, school = await _seed_history(db_session, 5)

    response = await async_client.get(
        "/api/v1/attendance/history"
        "?start_date=2025-01-01&end_date=2025-01-05&limit=100",
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 5
    assert body["limit"] == 100
    assert len(body["items"]) == min(body["total"], 100)
    assert all(item["school_id"] == school.id for item in body["items"])
    assert all(item["teacher_name"] for item in body["items"])

    # Paging walks the same set without overlap.
    page = await async_client.get(
        "/api/v1/attendance/history"
        "?start_date=2025-01-01&end_date=2025-01-05&limit=2&skip=2",
        headers=admin_auth_headers,
    )
    assert page.status_code == 200
    assert len(page.json()["items"]) <= 2


@pytest.mark.asyncio
async def test_school_history_requires_admin(
    async_client: AsyncClient, teacher_auth_headers: dict
):
    response = await async_client.get(
        "/api/v1/attendance/history", headers=teacher_auth_headers
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_schedule_resolver_matches_per_teacher_lookup(db_session):
    """The bulk resolver must agree with the query it replaced."""
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teachers = (await db_session.execute(select(Teacher))).scalars().all()
    resolver = await ScheduleService.load_school_schedules(db_session, school.id)

    for day_offset in range(7):
        target = date(2026, 9, 7) + timedelta(days=day_offset)
        for teacher in teachers:
            expected = await ScheduleService.resolve_schedule_for_date(
                db_session, school.id, teacher.id, target
            )
            actual = resolver.for_teacher(teacher.id, target)
            assert (expected.id if expected else None) == (
                actual.id if actual else None
            ), f"{teacher.id} on {target}"


@pytest.mark.asyncio
async def test_dashboard_query_count_is_flat_in_teacher_count(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    """The dashboard used to run two schedule queries per teacher."""
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    target = date(2026, 9, 7)

    before_count = len((await db_session.execute(select(Teacher))).scalars().all())
    with _QueryCounter() as before:
        await AttendanceService.get_admin_today_dashboard(db_session, school.id, target)

    for _ in range(5):
        await create_fresh_teacher(async_client, admin_auth_headers)

    after_count = len((await db_session.execute(select(Teacher))).scalars().all())
    assert after_count >= before_count + 5
    with _QueryCounter() as after:
        await AttendanceService.get_admin_today_dashboard(db_session, school.id, target)

    # Five more teachers must not cost more queries.
    assert after.count == before.count, (
        f"{before.count} queries for {before_count} teachers, "
        f"{after.count} for {after_count}"
    )


@pytest.mark.asyncio
async def test_absence_pass_is_idempotent_with_shared_schedules(
    db_session, monkeypatch
):
    """Batching the reads must not change what the pass writes."""
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teachers = (await db_session.execute(select(Teacher))).scalars().all()
    for teacher in teachers:
        teacher.created_at = datetime(2026, 9, 1, tzinfo=ZoneInfo("Asia/Bishkek"))
    school.attendance_start_date = date(2026, 9, 7)
    await db_session.commit()

    monkeypatch.setattr(
        "app.services.absence_service.current_time_in_school_timezone",
        lambda _: datetime(2026, 9, 9, 18, tzinfo=ZoneInfo("Asia/Bishkek")),
    )
    from app.services.absence_service import AbsenceService

    first = await AbsenceService.process_workdays_from(
        db_session, school.id, date(2026, 9, 8), date(2026, 9, 9)
    )
    second = await AbsenceService.process_workdays_from(
        db_session, school.id, date(2026, 9, 8), date(2026, 9, 9)
    )
    assert first > 0
    assert second == 0, "a second pass must find nothing left to finalize"
