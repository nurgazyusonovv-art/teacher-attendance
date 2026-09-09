from datetime import datetime
from zoneinfo import ZoneInfo
from unittest.mock import AsyncMock
from types import SimpleNamespace

import pytest
from sqlalchemy import select, delete
from app.models.school import School
from app.models.teacher import Teacher
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.services.attendance_service import AttendanceService


@pytest.mark.asyncio
@pytest.mark.parametrize('hour,expected', [(10, 'PENDING'), (16, 'PENDING'), (17, 'ABSENT'), (18, 'ABSENT')])
async def test_server_workday_boundary(db_session, monkeypatch, hour, expected):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teacher = (await db_session.execute(select(Teacher).limit(1))).scalar_one()
    monkeypatch.setattr('app.services.attendance_service.current_time_in_school_timezone',
                        lambda _: datetime(2026, 9, 7, hour, tzinfo=ZoneInfo('Asia/Bishkek')))
    result = await AttendanceService.get_today_status(db_session, teacher, school)
    assert result.display_status == expected
    assert not result.has_checked_in


@pytest.mark.asyncio
@pytest.mark.parametrize('kind', ['EXCUSED', 'ON_TIME', 'LATE', 'ABSENT', 'DAY_OFF', 'NO_SCHEDULE'])
async def test_explicit_status_and_schedule(db_session, monkeypatch, kind):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teacher = (await db_session.execute(select(Teacher).limit(1))).scalar_one()
    now = datetime(2026, 9, 7, 18, tzinfo=ZoneInfo('Asia/Bishkek'))
    await db_session.execute(delete(DailyAttendance).where(
        DailyAttendance.teacher_id == teacher.id, DailyAttendance.date == now.date()))
    await db_session.commit()
    monkeypatch.setattr('app.services.attendance_service.current_time_in_school_timezone', lambda _: now)
    if kind == 'NO_SCHEDULE':
        monkeypatch.setattr('app.services.attendance_service.ScheduleService.resolve_schedule_for_date', AsyncMock(return_value=None))
    elif kind == 'DAY_OFF':
        monkeypatch.setattr('app.services.attendance_service.ScheduleService.resolve_schedule_for_date',
                            AsyncMock(return_value=SimpleNamespace(is_day_off=True, start_time=None, end_time=None)))
    else:
        db_session.add(DailyAttendance(teacher_id=teacher.id, school_id=school.id,
            date=now.date(), status=AttendanceStatus(kind), late_minutes=0, worked_minutes=0,
            check_in_time=now if kind in ('ON_TIME', 'LATE') else None))
        await db_session.commit()
    result = await AttendanceService.get_today_status(db_session, teacher, school)
    assert result.display_status == kind
    if kind == 'NO_SCHEDULE':
        assert result.scheduled_start is None and result.scheduled_end is None
