from sqlalchemy import select
from app.models.leave_request import LeaveRequest
from app.models.daily_attendance import DailyAttendance
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User


class LeaveRepository:
    def __init__(self, db):
        self.db = db

    async def school(self, school_id):
        return await self.db.get(School, school_id)

    async def get(self, request_id, school_id):
        return (await self.db.execute(select(LeaveRequest).where(
            LeaveRequest.id == request_id, LeaveRequest.school_id == school_id
        ).with_for_update())).scalar_one_or_none()

    async def for_day(self, teacher_id, target_date):
        return (await self.db.execute(select(LeaveRequest).where(
            LeaveRequest.teacher_id == teacher_id, LeaveRequest.target_date == target_date
        ))).scalar_one_or_none()

    async def attendance(self, teacher_id, target_date):
        return (await self.db.execute(select(DailyAttendance).where(
            DailyAttendance.teacher_id == teacher_id, DailyAttendance.date == target_date
        ).with_for_update())).scalar_one_or_none()

    async def list(self, school_id, teacher_id=None, offset=0, limit=50):
        query = select(LeaveRequest, User.full_name).join(Teacher, Teacher.id == LeaveRequest.teacher_id).join(User, User.id == Teacher.user_id).where(LeaveRequest.school_id == school_id)
        if teacher_id:
            query = query.where(LeaveRequest.teacher_id == teacher_id)
        return (await self.db.execute(query.order_by(LeaveRequest.created_at.desc(), LeaveRequest.id).offset(offset).limit(limit))).all()
