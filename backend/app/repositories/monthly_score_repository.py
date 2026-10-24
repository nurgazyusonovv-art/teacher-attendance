from sqlalchemy import or_, select

from app.models.daily_attendance import DailyAttendance
from app.models.leave_request import LeaveRequest
from app.models.schedule import WorkSchedule
from app.services.schedule_service import ResolvedSchedules


class MonthlyScoreRepository:
    def __init__(self, db):
        self.db = db

    async def load(self, teacher, start, end):
        # Bounded month and teacher+date index; never query other teachers' data.
        records = (await self.db.execute(select(DailyAttendance).where(
            DailyAttendance.school_id == teacher.school_id,
            DailyAttendance.teacher_id == teacher.id,
            DailyAttendance.date >= start, DailyAttendance.date <= end,
        ))).scalars().all()
        schedules = (await self.db.execute(select(WorkSchedule).where(
            WorkSchedule.school_id == teacher.school_id,
            or_(WorkSchedule.teacher_id == teacher.id, WorkSchedule.teacher_id.is_(None)),
        ))).scalars().all()
        approved = (await self.db.execute(select(LeaveRequest.target_date).where(
            LeaveRequest.school_id == teacher.school_id,
            LeaveRequest.teacher_id == teacher.id,
            LeaveRequest.target_date >= start, LeaveRequest.target_date <= end,
            LeaveRequest.status == 'APPROVED',
        ))).scalars().all()
        return records, ResolvedSchedules(schedules), set(approved)
