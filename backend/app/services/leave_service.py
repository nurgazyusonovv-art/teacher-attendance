from datetime import timedelta
from sqlalchemy.exc import IntegrityError
from app.core.errors import AppException, ErrorCode
from app.core.timezone import current_time_in_school_timezone
from app.models.leave_request import LeaveRequest
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.repositories.leave_repository import LeaveRepository
from app.schemas.leave_request import LeaveRead
from app.services.attendance_service import AttendanceService
from app.services.schedule_service import ScheduleService
from app.services.audit_service import AuditService


class LeaveService:
    @staticmethod
    def conflict(message):
        return AppException(code=ErrorCode.VALIDATION_ERROR, message=message, status_code=409)

    @staticmethod
    async def list(db, school_id, teacher_id=None, offset=0, limit=50):
        rows = await LeaveRepository(db).list(school_id, teacher_id, offset, limit)
        return [LeaveRead.model_validate(row).model_copy(update={'teacher_name': name}) for row, name in rows]

    @staticmethod
    async def create(db, teacher, payload):
        repo = LeaveRepository(db)
        school = await repo.school(teacher.school_id)
        today = current_time_in_school_timezone(school.timezone).date()
        if not today <= payload.target_date <= today + timedelta(days=365):
            raise LeaveService.conflict('Бүгүнкү же алдыдагы бир жылдын күнүн тандаңыз.')
        await AttendanceService._lock_attendance_day(db, teacher.id, payload.target_date)
        existing = await repo.for_day(teacher.id, payload.target_date)
        if existing:
            if existing.reason == payload.reason:
                return LeaveRead.model_validate(existing)
            raise LeaveService.conflict('Бул күнгө арыз мурун жөнөтүлгөн.')
        schedule = await ScheduleService.resolve_schedule_for_date(db, school.id, teacher.id, payload.target_date)
        if schedule is None or schedule.is_day_off:
            raise LeaveService.conflict('Бул күнгө иш графиги жок же дем алыш күн.')
        daily = await repo.attendance(teacher.id, payload.target_date)
        if daily and (daily.check_in_time or daily.status == AttendanceStatus.EXCUSED):
            raise LeaveService.conflict('Бул күнгө каттоо же уруксат бар. Администраторго кайрылыңыз.')
        row = LeaveRequest(school_id=school.id, teacher_id=teacher.id,
                           target_date=payload.target_date, reason=payload.reason, status='PENDING')
        db.add(row)
        try:
            await db.flush()
            AuditService.add(db, school_id=school.id, user_id=teacher.user_id,
                action='LEAVE_REQUESTED', entity_name='leave_request', entity_id=row.id,
                new_values={'status': 'PENDING', 'date': payload.target_date})
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            raise LeaveService.conflict('Бул күнгө арыз мурун жөнөтүлгөн.') from exc
        await db.refresh(row)
        return LeaveRead.model_validate(row)

    @staticmethod
    async def decide(db, school_id, actor_id, request_id, payload):
        repo = LeaveRepository(db)
        row = await repo.get(request_id, school_id)
        if row is None:
            raise AppException(code=ErrorCode.NOT_FOUND, message='Арыз табылган жок.', status_code=404)
        if row.status != 'PENDING':
            if row.status == payload.status and row.decision_reason == payload.reason:
                return LeaveRead.model_validate(row)
            raise LeaveService.conflict('Бул арыз боюнча чечим мурда чыгарылган.')
        await AttendanceService._lock_attendance_day(db, row.teacher_id, row.target_date)
        school = await repo.school(school_id)
        if payload.status == 'APPROVED':
            schedule = await ScheduleService.resolve_schedule_for_date(db, school_id, row.teacher_id, row.target_date)
            if schedule is None or schedule.is_day_off:
                raise LeaveService.conflict('Бул күндүн иш графиги өзгөргөн. Арызды четке кагыңыз.')
            daily = await repo.attendance(row.teacher_id, row.target_date)
            if daily and daily.check_in_time:
                raise LeaveService.conflict('Мугалим бул күнгө катталган. Каттоону үнсүз өзгөртүүгө болбойт.')
            old = {'status': daily.status.value if daily else None}
            if daily is None:
                daily = DailyAttendance(teacher_id=row.teacher_id, school_id=school_id,
                    date=row.target_date, late_minutes=0, worked_minutes=0)
                db.add(daily)
            daily.status = AttendanceStatus.EXCUSED
            daily.is_manually_corrected = True
            daily.corrected_by_id = actor_id
            daily.correction_reason = payload.reason
            await db.flush()
            AuditService.add(db, school_id=school_id, user_id=actor_id,
                action='LEAVE_ATTENDANCE_EXCUSED', entity_name='daily_attendance', entity_id=daily.id,
                old_values=old, new_values={'status': 'EXCUSED', 'leave_request_id': row.id})
        row.status = payload.status
        row.decision_reason = payload.reason
        row.reviewed_by_id = actor_id
        row.reviewed_at = current_time_in_school_timezone(school.timezone)
        AuditService.add(db, school_id=school_id, user_id=actor_id,
            action='LEAVE_REVIEWED', entity_name='leave_request', entity_id=row.id,
            old_values={'status': 'PENDING'}, new_values={'status': row.status, 'reason': payload.reason})
        await db.commit()
        await db.refresh(row)
        return LeaveRead.model_validate(row)
