from datetime import date, datetime
from zoneinfo import ZoneInfo
import pytest
from sqlalchemy import select
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.models.daily_attendance import DailyAttendance
from app.models.audit import AuditLog
from app.models.enums import AttendanceStatus, UserRole
from app.services.absence_service import AbsenceService
from app.services.attendance_reset_service import AttendanceResetService
from app.core.errors import AppException


@pytest.mark.asyncio
async def test_closed_workday_and_excused_preservation(db_session, monkeypatch):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    teachers = (await db_session.execute(select(Teacher))).scalars().all()
    day = date(2026, 9, 7)
    for teacher in teachers:
        teacher.created_at = datetime(2026, 9, 1, tzinfo=ZoneInfo("Asia/Bishkek"))
    await db_session.commit()
    monkeypatch.setattr("app.services.absence_service.current_time_in_school_timezone",
                        lambda _: datetime(2026, 9, 7, 10, tzinfo=ZoneInfo("Asia/Bishkek")))
    assert await AbsenceService.process_daily_absences(db_session, school.id, day) == []
    db_session.add(DailyAttendance(teacher_id=teachers[0].id, school_id=school.id,
        date=day, status=AttendanceStatus.EXCUSED, late_minutes=0, worked_minutes=0,
        is_manually_corrected=True, correction_reason="Уруксат берилди"))
    await db_session.commit()
    monkeypatch.setattr("app.services.absence_service.current_time_in_school_timezone",
                        lambda _: datetime(2026, 9, 7, 18, tzinfo=ZoneInfo("Asia/Bishkek")))
    await AbsenceService.process_daily_absences(db_session, school.id, day)
    records = (await db_session.execute(select(DailyAttendance).where(DailyAttendance.date == day))).scalars().all()
    assert len(records) == len(teachers)
    assert next(r for r in records if r.teacher_id == teachers[0].id).status == AttendanceStatus.EXCUSED
    assert await AbsenceService.process_daily_absences(db_session, school.id, day) == []


@pytest.mark.asyncio
async def test_reset_confirmation_and_audit(db_session):
    school = (await db_session.execute(select(School).limit(1))).scalar_one()
    admin = (await db_session.execute(select(User).where(User.role == UserRole.ADMIN))).scalar_one()
    with pytest.raises(AppException):
        await AttendanceResetService.reset(db_session, school.id, admin.id, "wrong")
    result = await AttendanceResetService.reset(db_session, school.id, admin.id, "RESET ATTENDANCE")
    assert result["deleted"] >= 0
    audit = (await db_session.execute(select(AuditLog).where(AuditLog.action == "ATTENDANCE_RESET"))).scalar_one()
    assert audit.school_id == school.id
    assert (await db_session.execute(select(Teacher))).scalars().all()
