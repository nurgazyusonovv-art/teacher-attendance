from datetime import date
from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timezone import today_date_in_school_timezone
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.services.schedule_service import ScheduleService


class AbsenceService:
    @staticmethod
    async def process_daily_absences(
        db: AsyncSession, school_id: str, target_date: date | None = None
    ) -> List[DailyAttendance]:
        """
        Иш күнү аяктаганда келбеген (Check-in жасабаган) мугалимдерди автоматтык
        түрдө ABSENT катары аныктайт (Дем алыш күнү жана алдын ала EXCUSED болгондордон тышкары).
        """
        school_res = await db.execute(select(School).where(School.id == school_id))
        school = school_res.scalar_one()
        eval_date = target_date or today_date_in_school_timezone(school.timezone)

        # 1. Get all active teachers
        teachers_res = await db.execute(
            select(Teacher)
            .where(Teacher.school_id == school_id, Teacher.is_active == True)  # noqa: E712
            .options(selectinload(Teacher.user))
        )
        teachers = teachers_res.scalars().all()

        # 2. Get existing records for this date
        daily_res = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.school_id == school_id,
                DailyAttendance.date == eval_date,
            )
        )
        existing_records = {r.teacher_id: r for r in daily_res.scalars().all()}

        created_absences: List[DailyAttendance] = []

        for t in teachers:
            # Check schedule for this date
            schedule = await ScheduleService.resolve_schedule_for_date(
                db, school_id, t.id, eval_date
            )
            # Skip if day off
            if schedule and schedule.is_day_off:
                continue

            record = existing_records.get(t.id)
            if not record:
                # No record exists at all -> create ABSENT
                absent_record = DailyAttendance(
                    teacher_id=t.id,
                    school_id=school_id,
                    date=eval_date,
                    check_in_time=None,
                    check_out_time=None,
                    status=AttendanceStatus.ABSENT,
                    late_minutes=0,
                    worked_minutes=0,
                )
                db.add(absent_record)
                created_absences.append(absent_record)
            elif record.check_in_time is None and record.status != AttendanceStatus.EXCUSED:
                # Record exists but not checked in and not excused
                record.status = AttendanceStatus.ABSENT
                created_absences.append(record)

        if created_absences:
            await db.commit()

        return created_absences
