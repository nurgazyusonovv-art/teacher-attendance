from datetime import datetime, date
from zoneinfo import ZoneInfo
import pytest
from sqlalchemy import select, delete
from app.models.leave_request import LeaveRequest
from app.models.daily_attendance import DailyAttendance
from app.models.audit import AuditLog
from app.models.teacher import Teacher
from app.models.user import User
from app.models.enums import UserRole, AttendanceStatus
from app.schemas.leave_request import LeaveCreate, LeaveDecision
from app.services.leave_service import LeaveService
from app.core.errors import AppException


@pytest.mark.asyncio
async def test_role_guards(async_client, teacher_auth_headers, admin_auth_headers):
    assert (await async_client.get('/api/v1/leaves/mine')).status_code == 401
    assert (await async_client.get('/api/v1/leaves/admin', headers=teacher_auth_headers)).status_code == 403
    assert (await async_client.post('/api/v1/leaves/admin/unknown/decision', headers=teacher_auth_headers,
        json={'status': 'APPROVED', 'reason': 'Текшерүү себеби'})).status_code == 403
    assert (await async_client.post('/api/v1/leaves', headers=admin_auth_headers,
        json={'target_date': '2026-10-05', 'reason': 'Текшерүү себеби'})).status_code == 403
    assert (await async_client.get('/api/v1/leaves/admin?limit=100000', headers=admin_auth_headers)).status_code == 422


@pytest.mark.asyncio
@pytest.mark.parametrize('decision', ['APPROVED', 'REJECTED'])
async def test_review_atomic_audit_and_retry(db_session, monkeypatch, decision):
    teacher = (await db_session.execute(select(Teacher).limit(1))).scalar_one()
    admin = (await db_session.execute(select(User).where(User.role == UserRole.ADMIN))).scalar_one()
    day = date(2026, 10, 5)
    await db_session.execute(delete(LeaveRequest).where(LeaveRequest.target_date == day))
    await db_session.execute(delete(DailyAttendance).where(DailyAttendance.date == day))
    await db_session.commit()
    monkeypatch.setattr('app.services.leave_service.current_time_in_school_timezone', lambda _: datetime(2026, 10, 5, 10, tzinfo=ZoneInfo('Asia/Bishkek')))
    payload = LeaveCreate(target_date=day, reason='Үй-бүлөлүк себеп')
    row = await LeaveService.create(db_session, teacher, payload)
    assert row.status == 'PENDING'
    assert (await LeaveService.create(db_session, teacher, payload)).id == row.id
    assert (await db_session.execute(select(DailyAttendance).where(DailyAttendance.date == day))).scalar_one_or_none() is None
    with pytest.raises(AppException) as error:
        await LeaveService.decide(db_session, 'different-school', admin.id, row.id, LeaveDecision(status=decision, reason='Чечимдин себеби'))
    assert error.value.status_code == 404
    result = await LeaveService.decide(db_session, teacher.school_id, admin.id, row.id, LeaveDecision(status=decision, reason='Чечимдин себеби'))
    assert result.status == decision
    await LeaveService.decide(db_session, teacher.school_id, admin.id, row.id, LeaveDecision(status=decision, reason='Чечимдин себеби'))
    daily = (await db_session.execute(select(DailyAttendance).where(DailyAttendance.date == day))).scalar_one_or_none()
    assert (daily is not None) == (decision == 'APPROVED')
    if daily:
        assert daily.status == AttendanceStatus.EXCUSED
        assert daily.corrected_by_id == admin.id
    audits = (await db_session.execute(select(AuditLog).where(AuditLog.entity_id == row.id, AuditLog.action == 'LEAVE_REVIEWED'))).scalars().all()
    assert len(audits) == 1
    with pytest.raises(AppException):
        await LeaveService.decide(db_session, teacher.school_id, admin.id, row.id, LeaveDecision(status='REJECTED' if decision == 'APPROVED' else 'APPROVED', reason='Башка чечим'))


@pytest.mark.asyncio
async def test_dates_and_attendance_conflict(db_session, monkeypatch):
    teacher = (await db_session.execute(select(Teacher).limit(1))).scalar_one()
    admin = (await db_session.execute(select(User).where(User.role == UserRole.ADMIN))).scalar_one()
    monkeypatch.setattr('app.services.leave_service.current_time_in_school_timezone', lambda _: datetime(2026, 11, 2, 10, tzinfo=ZoneInfo('Asia/Bishkek')))
    for day in [date(2026, 11, 1), date(2028, 11, 2), date(2026, 11, 8)]:
        with pytest.raises(AppException):
            await LeaveService.create(db_session, teacher, LeaveCreate(target_date=day, reason='Текшерүү себеби'))
    row = await LeaveService.create(db_session, teacher, LeaveCreate(target_date=date(2026, 11, 2), reason='Текшерүү себеби'))
    db_session.add(DailyAttendance(teacher_id=teacher.id, school_id=teacher.school_id, date=row.target_date,
        check_in_time=datetime(2026, 11, 2, 8), status=AttendanceStatus.ON_TIME, late_minutes=0, worked_minutes=0))
    await db_session.commit()
    with pytest.raises(AppException):
        await LeaveService.decide(db_session, teacher.school_id, admin.id, row.id, LeaveDecision(status='APPROVED', reason='Бекитүү себеби'))
    await db_session.rollback()
    stored = await db_session.get(LeaveRequest, row.id)
    assert stored.status == 'PENDING'
