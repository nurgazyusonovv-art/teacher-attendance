from sqlalchemy import delete
from app.core.errors import AppException, ErrorCode
from app.models.daily_attendance import DailyAttendance
from app.models.attendance import AttendanceEvent
from app.models.lesson_delay import LessonDelay
from app.services.audit_service import AuditService


class AttendanceResetService:
    @staticmethod
    async def reset(db, school_id: str, actor_id: str, confirmation: str) -> dict:
        if confirmation != "RESET ATTENDANCE":
            raise AppException(code=ErrorCode.VALIDATION_ERROR,
                               message="Ырастоо сөзү туура эмес.", status_code=400)
        counts = {}
        for model in (LessonDelay, AttendanceEvent, DailyAttendance):
            result = await db.execute(delete(model).where(model.school_id == school_id))
            counts[model.__tablename__] = result.rowcount or 0
        AuditService.add(db, school_id=school_id, user_id=actor_id,
                         action="ATTENDANCE_RESET", entity_name="school",
                         entity_id=school_id, new_values=counts)
        await db.commit()
        return {"deleted": counts["daily_attendance"], "counts": counts}
