from datetime import date, datetime, time, timezone
from types import SimpleNamespace as NS
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import select

from app.models.teacher import Teacher
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.repositories.monthly_score_repository import MonthlyScoreRepository
from app.services.monthly_score_service import MonthlyScoreService
from app.services.schedule_service import ResolvedSchedules

TZ = ZoneInfo('Asia/Bishkek')


def calculate(records=(), approved=(), now=None, schedules=None, month=10, start=date(2026, 10, 1)):
    teacher = NS(id='teacher', created_at=datetime(2026, 1, 1, tzinfo=TZ))
    school = NS(timezone='Asia/Bishkek', attendance_start_date=start)
    if schedules is None:
        schedules = ResolvedSchedules([NS(teacher_id=None, day_of_week=i, start_time=time(8),
                                          end_time=time(17), is_day_off=False) for i in range(7)])
    return MonthlyScoreService.calculate(teacher, school, now or datetime(2026, 10, 1, 18, tzinfo=TZ),
                                         2026, month, records, schedules, set(approved))


def record(arrival=8, departure=17, late=0, status='ON_TIME', day=1):
    return NS(date=date(2026, 10, day),
              check_in_time=datetime(2026, 10, day, arrival, tzinfo=TZ) if arrival is not None else None,
              check_out_time=datetime(2026, 10, day, departure, tzinfo=TZ) if departure is not None else None,
              late_minutes=late, status=status)


@pytest.mark.parametrize('row,points,late,early', [
    (record(), 10, 0, 0), (record(arrival=9, late=60, status='LATE'), 5, 1, 0),
    (record(departure=16), 5, 0, 1), (record(arrival=9, departure=16, late=60, status='LATE'), 0, 1, 1),
    (record(departure=18), 10, 0, 0), (record(departure=None), 5, 0, 0),
])
def test_daily_rules(row, points, late, early):
    result = calculate([row])
    assert (result.points, result.late_days, result.early_departure_days) == (points, late, early)
    assert result.possible_points == 10


def test_absence_and_missing_checkout_finalized_only_after_shift():
    assert calculate().absent_days == 1
    pending = calculate(now=datetime(2026, 10, 1, 12, tzinfo=TZ))
    assert pending.absent_days == 0 and pending.days[0].pending
    assert calculate([record(departure=None)]).missing_checkout_days == 1


def test_excused_day_off_and_missing_schedule_are_excluded():
    assert calculate(approved=[date(2026, 10, 1)]).possible_points == 0
    assert calculate([record(arrival=None, departure=None, status='EXCUSED')]).excused_days == 1
    assert calculate([record(status='DAY_OFF')]).possible_points == 0
    assert calculate(schedules=ResolvedSchedules([])).unscored_days == 1


def test_timezone_and_exact_departure_boundary():
    row = record()
    row.check_out_time = datetime(2026, 10, 1, 11, tzinfo=timezone.utc)
    assert calculate([row]).points == 10
    row.check_out_time = datetime(2026, 10, 1, 10, 59, 59, tzinfo=timezone.utc)
    assert calculate([row]).points == 5


def test_months_reset_no_future_days_and_no_pre_start_penalty():
    result = calculate([record()], now=datetime(2026, 10, 2, 18, tzinfo=TZ))
    assert result.points == 10 and result.possible_points == 20
    assert len(result.days) == 2
    assert calculate(month=9).points == 0
    assert calculate(start=date(2026, 10, 2)).possible_points == 0


def test_repeated_calculation_is_idempotent_and_corrections_recalculate():
    row = record()
    assert calculate([row]).model_dump() == calculate([row]).model_dump()
    row.status, row.late_minutes = 'LATE', 10
    assert calculate([row]).points == 5


def test_teacher_schedule_overrides_school_schedule():
    schedules = ResolvedSchedules([
        NS(teacher_id=None, day_of_week=3, end_time=time(17), is_day_off=False),
        NS(teacher_id='teacher', day_of_week=3, end_time=time(16), is_day_off=False),
    ])
    assert calculate([record(departure=16)], schedules=schedules).points == 10


@pytest.mark.asyncio
async def test_score_auth_and_query_validation(async_client, teacher_auth_headers, admin_auth_headers):
    url = '/api/v1/attendance/my-monthly-score'
    assert (await async_client.get(url)).status_code == 401
    assert (await async_client.get(url, headers=admin_auth_headers)).status_code == 403
    assert (await async_client.get(url + '?year=2026', headers=teacher_auth_headers)).status_code == 422
    assert (await async_client.get(url + '?year=9998&month=1', headers=teacher_auth_headers)).status_code == 422
    response = await async_client.get(url, headers=teacher_auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert data['rule_version'] == 'monthly-5-plus-5-v1'


@pytest.mark.asyncio
async def test_repository_does_not_mix_demo_and_teacher(db_session):
    teachers = (await db_session.execute(select(Teacher))).scalars().all()
    a, b = teachers[:2]
    day = date(2030, 1, 1)
    rows = [DailyAttendance(teacher_id=t.id, school_id=t.school_id, date=day,
                            status=AttendanceStatus.ON_TIME, late_minutes=0, worked_minutes=0) for t in (a, b)]
    db_session.add_all(rows)
    await db_session.flush()
    found, _, _ = await MonthlyScoreRepository(db_session).load(a, day, day)
    assert [r.teacher_id for r in found] == [a.id]
    await db_session.rollback()
