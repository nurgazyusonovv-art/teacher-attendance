from datetime import date
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppException, ErrorCode
from app.models.schedule import WorkSchedule
from app.models.school import School
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate


class ScheduleService:
    @staticmethod
    async def get_schedules_for_school(
        db: AsyncSession, school_id: str, teacher_id: Optional[str] = None
    ) -> List[WorkSchedule]:
        query = select(WorkSchedule).where(WorkSchedule.school_id == school_id)
        if teacher_id:
            query = query.where(WorkSchedule.teacher_id == teacher_id)
        else:
            query = query.where(WorkSchedule.teacher_id.is_(None))

        query = query.order_by(WorkSchedule.day_of_week.asc())
        result = await db.execute(query)
        return list(result.scalars().all())

    @staticmethod
    async def create_or_update_schedule(
        db: AsyncSession, payload: ScheduleCreate
    ) -> WorkSchedule:
        school_id = payload.school_id
        if not school_id:
            first_school = await db.execute(select(School).limit(1))
            s = first_school.scalar_one_or_none()
            if not s:
                raise AppException(
                    code=ErrorCode.NOT_FOUND,
                    message="Мектеп табылган жок",
                    status_code=400,
                )
            school_id = s.id

        # Check if existing schedule for this day
        query = select(WorkSchedule).where(
            WorkSchedule.school_id == school_id,
            WorkSchedule.day_of_week == payload.day_of_week,
        )
        if payload.teacher_id:
            query = query.where(WorkSchedule.teacher_id == payload.teacher_id)
        else:
            query = query.where(WorkSchedule.teacher_id.is_(None))

        result = await db.execute(query)
        existing = result.scalar_one_or_none()

        if existing:
            existing.start_time = payload.start_time
            existing.end_time = payload.end_time
            existing.grace_minutes = payload.grace_minutes
            existing.is_day_off = payload.is_day_off
            await db.commit()
            await db.refresh(existing)
            return existing

        schedule = WorkSchedule(
            school_id=school_id,
            teacher_id=payload.teacher_id,
            day_of_week=payload.day_of_week,
            start_time=payload.start_time,
            end_time=payload.end_time,
            grace_minutes=payload.grace_minutes,
            is_day_off=payload.is_day_off,
        )
        db.add(schedule)
        await db.commit()
        await db.refresh(schedule)
        return schedule

    @staticmethod
    async def update_schedule(
        db: AsyncSession, schedule_id: str, payload: ScheduleUpdate
    ) -> WorkSchedule:
        result = await db.execute(
            select(WorkSchedule).where(WorkSchedule.id == schedule_id)
        )
        schedule = result.scalar_one_or_none()
        if not schedule:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="График табылган жок",
                status_code=404,
            )

        update_data = payload.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(schedule, field, value)

        await db.commit()
        await db.refresh(schedule)
        return schedule

    @staticmethod
    async def delete_schedule(db: AsyncSession, schedule_id: str) -> None:
        result = await db.execute(
            select(WorkSchedule).where(WorkSchedule.id == schedule_id)
        )
        schedule = result.scalar_one_or_none()
        if not schedule:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="График табылган жок",
                status_code=404,
            )
        await db.delete(schedule)
        await db.commit()

    @staticmethod
    async def resolve_schedule_for_date(
        db: AsyncSession, school_id: str, teacher_id: Optional[str], target_date: date
    ) -> Optional[WorkSchedule]:
        """
        Күндөлүк графикти чечмелейт:
        1. Адегенде мугалимдин жеке графигин издейт (эгер бар болсо)
        2. Андан соң мектептин жалпы жумалык графигин карайт.
        """
        day_of_week = target_date.weekday()  # 0=Monday, 6=Sunday

        # 1. Teacher custom schedule
        if teacher_id:
            teacher_query = select(WorkSchedule).where(
                WorkSchedule.school_id == school_id,
                WorkSchedule.teacher_id == teacher_id,
                WorkSchedule.day_of_week == day_of_week,
            )
            teacher_res = await db.execute(teacher_query)
            custom_sched = teacher_res.scalar_one_or_none()
            if custom_sched:
                return custom_sched

        # 2. School default schedule
        school_query = select(WorkSchedule).where(
            WorkSchedule.school_id == school_id,
            WorkSchedule.teacher_id.is_(None),
            WorkSchedule.day_of_week == day_of_week,
        )
        school_res = await db.execute(school_query)
        return school_res.scalar_one_or_none()
