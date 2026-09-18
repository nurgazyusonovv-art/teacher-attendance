from datetime import date, time
from typing import Dict, Iterable, List, Optional, Tuple
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppException, ErrorCode
from app.models.schedule import WorkSchedule
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate
from app.services.audit_service import AuditService


class ResolvedSchedules:
    """Every schedule of one school, indexed for lookup without more queries.

    Resolving a schedule per teacher per day cost two queries each, so an
    admin dashboard or a multi-day absence pass scaled linearly in round
    trips. Load the school's schedules once and answer from memory instead.
    """

    __slots__ = ("_by_day_teacher", "_defaults_by_day")

    def __init__(self, rows: Iterable[WorkSchedule]):
        self._by_day_teacher: Dict[Tuple[int, str], WorkSchedule] = {}
        self._defaults_by_day: Dict[int, WorkSchedule] = {}
        for row in rows:
            if row.teacher_id is None:
                self._defaults_by_day[row.day_of_week] = row
            else:
                self._by_day_teacher[(row.day_of_week, row.teacher_id)] = row

    def for_teacher(
        self, teacher_id: Optional[str], target_date: date
    ) -> Optional[WorkSchedule]:
        """Teacher override first, then the school default for that weekday."""
        day_of_week = target_date.weekday()
        if teacher_id is not None:
            override = self._by_day_teacher.get((day_of_week, teacher_id))
            if override is not None:
                return override
        return self._defaults_by_day.get(day_of_week)


class ScheduleService:
    @staticmethod
    async def get_schedules_for_school(
        db: AsyncSession, school_id: str, teacher_id: Optional[str] = None
    ) -> List[WorkSchedule]:
        if not teacher_id:
            query = (
                select(WorkSchedule)
                .where(
                    WorkSchedule.school_id == school_id,
                    WorkSchedule.teacher_id.is_(None),
                )
                .order_by(WorkSchedule.day_of_week.asc())
            )
            result = await db.execute(query)
            return list(result.scalars().all())

        # If teacher_id is provided:
        # 1. Fetch school default schedules
        school_res = await db.execute(
            select(WorkSchedule)
            .where(
                WorkSchedule.school_id == school_id,
                WorkSchedule.teacher_id.is_(None),
            )
            .order_by(WorkSchedule.day_of_week.asc())
        )
        school_schedules = {s.day_of_week: s for s in school_res.scalars().all()}

        # 2. Fetch teacher custom overrides
        teacher_res = await db.execute(
            select(WorkSchedule)
            .where(
                WorkSchedule.school_id == school_id,
                WorkSchedule.teacher_id == teacher_id,
            )
            .order_by(WorkSchedule.day_of_week.asc())
        )
        teacher_schedules = {s.day_of_week: s for s in teacher_res.scalars().all()}

        # 3. Merge: If teacher has custom schedule for day, use it. Otherwise, use school default schedule.
        merged: List[WorkSchedule] = []
        for day in range(7):
            if day in teacher_schedules:
                merged.append(teacher_schedules[day])
            elif day in school_schedules:
                merged.append(school_schedules[day])

        return merged

    @staticmethod
    async def create_or_update_schedule(
        db: AsyncSession,
        payload: ScheduleCreate,
        actor_user_id: Optional[str] = None,
    ) -> WorkSchedule:
        school_id = payload.school_id
        if not school_id:
            raise AppException(
                code=ErrorCode.VALIDATION_ERROR,
                message="График үчүн мектеп ID талап кылынат.",
                status_code=400,
            )

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

        start_t = payload.start_time
        end_t = payload.end_time
        if not start_t:
            from datetime import time as dt_time
            start_t = dt_time(8, 0)
        if not end_t:
            from datetime import time as dt_time
            end_t = dt_time(17, 0)
        ScheduleService._validate_work_period(start_t, end_t, payload.is_day_off)

        if existing:
            old_values = {
                "start_time": existing.start_time,
                "end_time": existing.end_time,
                "grace_minutes": existing.grace_minutes,
                "is_day_off": existing.is_day_off,
            }
            existing.start_time = start_t
            existing.end_time = end_t
            existing.grace_minutes = payload.grace_minutes
            existing.is_day_off = payload.is_day_off
            AuditService.add(
                db,
                school_id=school_id,
                user_id=actor_user_id,
                action="SCHEDULE_UPDATED",
                entity_name="work_schedule",
                entity_id=existing.id,
                old_values=old_values,
                new_values=payload.model_dump(exclude={"school_id"}),
            )
            await db.commit()
            await db.refresh(existing)
            return existing

        schedule = WorkSchedule(
            school_id=school_id,
            teacher_id=payload.teacher_id,
            day_of_week=payload.day_of_week,
            start_time=start_t,
            end_time=end_t,
            grace_minutes=payload.grace_minutes,
            is_day_off=payload.is_day_off,
        )
        db.add(schedule)
        await db.flush()
        AuditService.add(
            db,
            school_id=school_id,
            user_id=actor_user_id,
            action="SCHEDULE_CREATED",
            entity_name="work_schedule",
            entity_id=schedule.id,
            new_values=payload.model_dump(),
        )
        await db.commit()
        await db.refresh(schedule)
        return schedule

    @staticmethod
    async def update_schedule(
        db: AsyncSession,
        schedule_id: str,
        payload: ScheduleUpdate,
        actor_user_id: Optional[str] = None,
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
        if update_data.get("start_time") is None:
            update_data.pop("start_time", None)
        if update_data.get("end_time") is None:
            update_data.pop("end_time", None)
        next_start = update_data.get("start_time", schedule.start_time)
        next_end = update_data.get("end_time", schedule.end_time)
        next_day_off = update_data.get("is_day_off", schedule.is_day_off)
        ScheduleService._validate_work_period(next_start, next_end, next_day_off)
        old_values = {field: getattr(schedule, field) for field in update_data}
        for field, value in update_data.items():
            setattr(schedule, field, value)

        AuditService.add(
            db,
            school_id=schedule.school_id,
            user_id=actor_user_id,
            action="SCHEDULE_UPDATED",
            entity_name="work_schedule",
            entity_id=schedule.id,
            old_values=old_values,
            new_values=update_data,
        )

        await db.commit()
        await db.refresh(schedule)
        return schedule

    @staticmethod
    async def delete_schedule(
        db: AsyncSession, schedule_id: str, actor_user_id: Optional[str] = None
    ) -> None:
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
        AuditService.add(
            db,
            school_id=schedule.school_id,
            user_id=actor_user_id,
            action="SCHEDULE_DELETED",
            entity_name="work_schedule",
            entity_id=schedule.id,
            old_values={
                "day_of_week": schedule.day_of_week,
                "teacher_id": schedule.teacher_id,
            },
        )
        await db.delete(schedule)
        await db.commit()

    @staticmethod
    async def load_school_schedules(
        db: AsyncSession, school_id: str
    ) -> ResolvedSchedules:
        """Loads every schedule of a school in one query.

        Use this instead of calling resolve_schedule_for_date in a loop.
        """
        rows = await db.execute(
            select(WorkSchedule).where(WorkSchedule.school_id == school_id)
        )
        return ResolvedSchedules(rows.scalars().all())

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

    @staticmethod
    def _validate_work_period(
        start_time: Optional[time], end_time: Optional[time], is_day_off: bool
    ) -> None:
        if not is_day_off and (start_time is None or end_time is None or start_time >= end_time):
            raise AppException(
                code=ErrorCode.VALIDATION_ERROR,
                message="Иш күнүндө аяктоо убактысы баштоо убактысынан кийин болушу керек.",
                status_code=400,
            )
