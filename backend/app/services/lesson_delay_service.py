from datetime import date
from typing import List, Optional
from sqlalchemy import select, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppException, ErrorCode
from app.models.lesson_delay import LessonDelay
from app.models.teacher import Teacher
from app.schemas.lesson_delay import LessonDelayCreate, LessonDelayRead


class LessonDelayService:
    @staticmethod
    async def create_lesson_delay(
        db: AsyncSession,
        payload: LessonDelayCreate,
        recorded_by_user_id: Optional[str] = None,
    ) -> LessonDelayRead:
        # Check teacher exists
        teacher_stmt = (
            select(Teacher)
            .options(selectinload(Teacher.user))
            .where(Teacher.id == payload.teacher_id)
        )
        teacher_result = await db.execute(teacher_stmt)
        teacher = teacher_result.scalar_one_or_none()
        if not teacher:
            raise AppException(
                code=ErrorCode.TEACHER_NOT_FOUND,
                message="Мугалим табылган жок",
                status_code=404,
            )

        # Check existing delay for this teacher on this lesson and date
        existing_stmt = select(LessonDelay).where(
            LessonDelay.teacher_id == payload.teacher_id,
            LessonDelay.date == payload.date,
            LessonDelay.lesson_number == payload.lesson_number,
        )
        existing_result = await db.execute(existing_stmt)
        existing = existing_result.scalar_one_or_none()

        if existing:
            # Update existing lesson delay
            existing.delay_minutes = payload.delay_minutes
            existing.reason = payload.reason
            existing.recorded_by_user_id = recorded_by_user_id
            await db.commit()
            await db.refresh(existing)
            return LessonDelayRead(
                id=existing.id,
                teacher_id=existing.teacher_id,
                school_id=existing.school_id,
                date=existing.date,
                lesson_number=existing.lesson_number,
                delay_minutes=existing.delay_minutes,
                reason=existing.reason,
                recorded_by_user_id=existing.recorded_by_user_id,
                teacher_name=teacher.user.full_name if teacher.user else None,
                created_at=existing.created_at,
            )

        # Create new lesson delay
        delay = LessonDelay(
            teacher_id=teacher.id,
            school_id=teacher.school_id,
            date=payload.date,
            lesson_number=payload.lesson_number,
            delay_minutes=payload.delay_minutes,
            reason=payload.reason,
            recorded_by_user_id=recorded_by_user_id,
        )
        db.add(delay)
        await db.commit()
        await db.refresh(delay)

        return LessonDelayRead(
            id=delay.id,
            teacher_id=delay.teacher_id,
            school_id=delay.school_id,
            date=delay.date,
            lesson_number=delay.lesson_number,
            delay_minutes=delay.delay_minutes,
            reason=delay.reason,
            recorded_by_user_id=delay.recorded_by_user_id,
            teacher_name=teacher.user.full_name if teacher.user else None,
            created_at=delay.created_at,
        )

    @staticmethod
    async def get_lesson_delays_for_teacher(
        db: AsyncSession,
        teacher_id: str,
        target_date: Optional[date] = None,
        year: Optional[int] = None,
        month: Optional[int] = None,
    ) -> List[LessonDelayRead]:
        query = (
            select(LessonDelay)
            .options(selectinload(LessonDelay.teacher).selectinload(Teacher.user))
            .where(LessonDelay.teacher_id == teacher_id)
        )
        if target_date:
            query = query.where(LessonDelay.date == target_date)
        elif year and month:
            from sqlalchemy import extract
            query = query.where(
                extract("year", LessonDelay.date) == year,
                extract("month", LessonDelay.date) == month,
            )

        query = query.order_by(LessonDelay.date.asc(), LessonDelay.lesson_number.asc())
        result = await db.execute(query)
        delays = result.scalars().all()

        return [
            LessonDelayRead(
                id=d.id,
                teacher_id=d.teacher_id,
                school_id=d.school_id,
                date=d.date,
                lesson_number=d.lesson_number,
                delay_minutes=d.delay_minutes,
                reason=d.reason,
                recorded_by_user_id=d.recorded_by_user_id,
                teacher_name=d.teacher.user.full_name if (d.teacher and d.teacher.user) else None,
                created_at=d.created_at,
            )
            for d in delays
        ]

    @staticmethod
    async def get_lesson_delays_for_school(
        db: AsyncSession,
        school_id: str,
        target_date: date,
    ) -> List[LessonDelayRead]:
        query = (
            select(LessonDelay)
            .options(selectinload(LessonDelay.teacher).selectinload(Teacher.user))
            .where(
                LessonDelay.school_id == school_id,
                LessonDelay.date == target_date,
            )
            .order_by(LessonDelay.lesson_number.asc())
        )
        result = await db.execute(query)
        delays = result.scalars().all()

        return [
            LessonDelayRead(
                id=d.id,
                teacher_id=d.teacher_id,
                school_id=d.school_id,
                date=d.date,
                lesson_number=d.lesson_number,
                delay_minutes=d.delay_minutes,
                reason=d.reason,
                recorded_by_user_id=d.recorded_by_user_id,
                teacher_name=d.teacher.user.full_name if (d.teacher and d.teacher.user) else None,
                created_at=d.created_at,
            )
            for d in delays
        ]

    @staticmethod
    async def delete_lesson_delay(db: AsyncSession, delay_id: str) -> bool:
        stmt = delete(LessonDelay).where(LessonDelay.id == delay_id)
        result = await db.execute(stmt)
        await db.commit()
        return result.rowcount > 0
