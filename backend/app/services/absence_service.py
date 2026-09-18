from datetime import date, timedelta
from typing import List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.timezone import current_time_in_school_timezone, to_school_timezone
from app.core.errors import AppException, ErrorCode
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.models.audit import AuditLog
from app.services.schedule_service import ResolvedSchedules, ScheduleService

MAX_CATCH_UP_DAYS = 366


class AbsenceService:
    @staticmethod
    def resolve_start_date(school: School) -> date:
        """First day this school may be evaluated for absences.

        Configured per school; falls back to the school creation date so a
        newly onboarded school is never back-filled with absences it predates.
        """
        if school.attendance_start_date:
            return school.attendance_start_date
        if school.created_at:
            return to_school_timezone(school.created_at, school.timezone).date()
        return current_time_in_school_timezone(school.timezone).date()

    @staticmethod
    async def catch_up(db: AsyncSession, school_id: str) -> int:
        """Finalizes every unprocessed workday since the last attendance reset."""
        school = (
            await db.execute(select(School).where(School.id == school_id))
        ).scalar_one()
        end = current_time_in_school_timezone(school.timezone).date()

        reset = (
            await db.execute(
                select(AuditLog.created_at)
                .where(
                    AuditLog.school_id == school_id,
                    AuditLog.action == "ATTENDANCE_RESET",
                )
                .order_by(AuditLog.created_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()

        start = AbsenceService.resolve_start_date(school)
        if reset:
            start = max(start, to_school_timezone(reset, school.timezone).date())
        if end < start:
            return 0
        return await AbsenceService.process_workdays_from(
            db, school_id, start, min(end, start + timedelta(days=MAX_CATCH_UP_DAYS))
        )

    @staticmethod
    async def process_workdays_from(
        db: AsyncSession, school_id: str, start_date: date, end_date: date
    ) -> int:
        """Finalize every scheduled workday in an explicit, bounded range."""
        if end_date < start_date or (end_date - start_date).days > MAX_CATCH_UP_DAYS:
            raise AppException(
                code=ErrorCode.VALIDATION_ERROR,
                message="Күндөрдүн аралыгы туура эмес.",
                status_code=400,
            )
        # Loaded once for the whole range rather than per day per teacher.
        schedules = await ScheduleService.load_school_schedules(db, school_id)
        teachers = list(
            (
                await db.execute(
                    select(Teacher)
                    .where(
                        Teacher.school_id == school_id,
                        Teacher.is_active == True,  # noqa: E712
                    )
                    .options(selectinload(Teacher.user))
                )
            )
            .scalars()
            .all()
        )
        total = 0
        current = start_date
        while current <= end_date:
            total += len(
                await AbsenceService.process_daily_absences(
                    db, school_id, current, schedules, teachers
                )
            )
            current += timedelta(days=1)
        return total

    @staticmethod
    async def process_daily_absences(
        db: AsyncSession,
        school_id: str,
        target_date: date | None = None,
        schedules: ResolvedSchedules | None = None,
        teachers: List[Teacher] | None = None,
    ) -> List[DailyAttendance]:
        """
        Иш күнү аяктаганда келбеген (Check-in жасабаган) мугалимдерди автоматтык
        түрдө ABSENT катары аныктайт (Дем алыш күнү жана алдын ала EXCUSED болгондордон тышкары).
        """
        school_res = await db.execute(select(School).where(School.id == school_id))
        school = school_res.scalar_one()
        if schedules is None:
            schedules = await ScheduleService.load_school_schedules(db, school_id)
        now = current_time_in_school_timezone(school.timezone)
        eval_date = target_date or now.date()
        if eval_date < AbsenceService.resolve_start_date(school) or eval_date > now.date():
            return []

        # 1. Get all active teachers
        if teachers is None:
            teachers_res = await db.execute(
                select(Teacher)
                .where(Teacher.school_id == school_id, Teacher.is_active == True)  # noqa: E712
                .options(selectinload(Teacher.user))
            )
            teachers = list(teachers_res.scalars().all())

        # 2. Narrow to the teachers this day could actually mark absent, so the
        #    row lock and re-read below run for those only rather than for
        #    every teacher on every day of a long catch-up range.
        candidates: List[Teacher] = []
        for t in teachers:
            if t.created_at and eval_date < to_school_timezone(t.created_at, school.timezone).date():
                continue
            schedule = schedules.for_teacher(t.id, eval_date)
            # Missing schedules and explicit days off are never inferred as absences.
            if schedule is None or schedule.is_day_off:
                continue
            if eval_date == now.date() and now.time().replace(tzinfo=None) < schedule.end_time:
                continue
            candidates.append(t)

        if not candidates:
            return []

        # 3. One read for the whole day instead of one per teacher. It only
        #    decides who is worth locking; the authoritative read happens
        #    under the lock, because a scan may land in between.
        existing_rows = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.school_id == school_id,
                DailyAttendance.date == eval_date,
            )
        )
        prefetched = {row.teacher_id: row for row in existing_rows.scalars().all()}

        created_absences: List[DailyAttendance] = []
        from app.services.attendance_service import AttendanceService

        for t in candidates:
            known = prefetched.get(t.id)
            if known is not None and (
                known.check_in_time is not None
                or known.status in (AttendanceStatus.EXCUSED, AttendanceStatus.ABSENT)
            ):
                # Already settled; nothing this pass would change.
                continue

            await AttendanceService._lock_attendance_day(db, t.id, eval_date)
            record = (await db.execute(select(DailyAttendance).where(
                DailyAttendance.teacher_id == t.id, DailyAttendance.date == eval_date
            ).execution_options(populate_existing=True))).scalar_one_or_none()
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
            elif record.check_in_time is None and record.status not in (AttendanceStatus.EXCUSED, AttendanceStatus.ABSENT):
                # Record exists but not checked in and not excused
                record.status = AttendanceStatus.ABSENT
                created_absences.append(record)

        if created_absences:
            await db.commit()

        return created_absences
