import json
from datetime import date, datetime, time, timedelta
from typing import List, Optional, Tuple
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppException, ErrorCode
from app.core.timezone import (
    current_time_in_school_timezone,
    today_date_in_school_timezone,
    to_school_timezone,
)
from app.models.attendance import AttendanceEvent
from app.models.audit import AuditLog
from app.models.daily_attendance import DailyAttendance
from app.models.enums import AttendanceEventType, AttendanceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.schemas.attendance import (
    AdminDashboardSummary,
    AttendanceScanRequest,
    DailyAttendanceRead,
    ManualCorrectionRequest,
    TodayStatusResponse,
)
from app.services.geofence_service import GeofenceService
from app.services.qr_service import QrService
from app.services.schedule_service import ScheduleService


class AttendanceService:
    @staticmethod
    async def register_check_in(
        db: AsyncSession,
        teacher: Teacher,
        user: User,
        payload: AttendanceScanRequest,
    ) -> DailyAttendanceRead:
        # 1. School check
        school_result = await db.execute(
            select(School).where(School.id == payload.school_id)
        )
        school = school_result.scalar_one_or_none()
        if not school:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="Мектеп табылган жок",
                status_code=404,
            )

        if teacher.school_id != school.id:
            raise AppException(
                code=ErrorCode.QR_WRONG_SCHOOL,
                message="Сиз башка мектептин QR-кодун сканерледиңиз",
                status_code=400,
            )

        # 2. QR Token validation
        await QrService.validate_qr_token(db, school.id, payload.qr_token)

        # 3. GPS Geofence validation (AGENTS.md #6)
        distance = GeofenceService.calculate_haversine_distance(
            lat1=school.latitude,
            lon1=school.longitude,
            lat2=payload.latitude,
            lon2=payload.longitude,
        )

        # Demo mode bypass (AGENTS.md #17: dedicated demo teacher can test anywhere)
        if not user.is_demo:
            if payload.accuracy > school.max_accuracy_meters:
                raise AppException(
                    code=ErrorCode.LOCATION_ACCURACY_TOO_LOW,
                    message=f"GPS тактыгы жетишсиз ({payload.accuracy:.1f}м > {school.max_accuracy_meters:.0f}м). Ачык жерге чыгып кайталаңыз.",
                    status_code=400,
                )

            if distance > school.allowed_radius_meters:
                raise AppException(
                    code=ErrorCode.LOCATION_OUTSIDE_SCHOOL,
                    message=f"Сиз мектептин аймагынан тышкарысыз (Аралык: {distance:.1f}м, уруксат: {school.allowed_radius_meters:.0f}м).",
                    status_code=400,
                )

        # 4. Authoritative Server Time & Date (AGENTS.md #5)
        server_now = current_time_in_school_timezone(school.timezone)
        today = server_now.date()

        # 5. Duplicate Check-in Check
        daily_res = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher.id,
                DailyAttendance.date == today,
            )
        )
        daily = daily_res.scalar_one_or_none()
        if daily and daily.check_in_time is not None:
            raise AppException(
                code=ErrorCode.ALREADY_CHECKED_IN,
                message=f"Сиз бүгүн саат {daily.check_in_time.strftime('%H:%M')}де катталгансыз.",
                status_code=400,
            )

        # 6. Schedule & Status calculation
        schedule = await ScheduleService.resolve_schedule_for_date(
            db=db,
            school_id=school.id,
            teacher_id=teacher.id,
            target_date=today,
        )

        scheduled_start = schedule.start_time if schedule else school.default_start_time
        grace = schedule.grace_minutes if schedule else school.grace_minutes

        current_time_val = server_now.time()
        start_threshold = (
            datetime.combine(today, scheduled_start) + timedelta(minutes=grace)
        ).time()

        if current_time_val <= start_threshold:
            status = AttendanceStatus.ON_TIME
            late_minutes = 0
        else:
            status = AttendanceStatus.LATE
            actual_dt = datetime.combine(today, current_time_val)
            expected_dt = datetime.combine(today, scheduled_start)
            late_minutes = max(0, int((actual_dt - expected_dt).total_seconds() / 60))

        # 7. Record AttendanceEvent (Without storing raw GPS!)
        event = AttendanceEvent(
            teacher_id=teacher.id,
            school_id=school.id,
            event_type=AttendanceEventType.CHECK_IN,
            event_time=server_now,
            status=status,
            late_minutes=late_minutes,
            distance_meters=distance,
            location_accuracy_meters=payload.accuracy,
            location_verified=True,
            qr_verified=True,
            device_info=payload.device_info,
        )
        db.add(event)

        # 8. Record DailyAttendance
        if not daily:
            daily = DailyAttendance(
                teacher_id=teacher.id,
                school_id=school.id,
                date=today,
                check_in_time=server_now,
                status=status,
                late_minutes=late_minutes,
            )
            db.add(daily)
        else:
            daily.check_in_time = server_now
            daily.status = status
            daily.late_minutes = late_minutes

        await db.commit()
        await db.refresh(daily)

        return DailyAttendanceRead(
            id=daily.id,
            teacher_id=daily.teacher_id,
            school_id=daily.school_id,
            date=daily.date,
            check_in_time=daily.check_in_time,
            check_out_time=daily.check_out_time,
            status=daily.status,
            late_minutes=daily.late_minutes,
            worked_minutes=daily.worked_minutes,
            is_manually_corrected=daily.is_manually_corrected,
            correction_reason=daily.correction_reason,
            teacher_name=user.full_name,
            employee_code=teacher.employee_code,
        )

    @staticmethod
    async def register_check_out(
        db: AsyncSession,
        teacher: Teacher,
        user: User,
        payload: AttendanceScanRequest,
    ) -> DailyAttendanceRead:
        # 1. School check
        school_result = await db.execute(
            select(School).where(School.id == payload.school_id)
        )
        school = school_result.scalar_one_or_none()
        if not school:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="Мектеп табылган жок",
                status_code=404,
            )

        if teacher.school_id != school.id:
            raise AppException(
                code=ErrorCode.QR_WRONG_SCHOOL,
                message="Сиз башка мектептин QR-кодун сканерледиңиз",
                status_code=400,
            )

        # 2. QR validation
        await QrService.validate_qr_token(db, school.id, payload.qr_token)

        # 3. GPS Geofence validation
        distance = GeofenceService.calculate_haversine_distance(
            lat1=school.latitude,
            lon1=school.longitude,
            lat2=payload.latitude,
            lon2=payload.longitude,
        )

        if not user.is_demo:
            if payload.accuracy > school.max_accuracy_meters:
                raise AppException(
                    code=ErrorCode.LOCATION_ACCURACY_TOO_LOW,
                    message=f"GPS тактыгы жетишсиз ({payload.accuracy:.1f}м).",
                    status_code=400,
                )

            if distance > school.allowed_radius_meters:
                raise AppException(
                    code=ErrorCode.LOCATION_OUTSIDE_SCHOOL,
                    message=f"Сиз мектептин аймагынан тышкарысыз ({distance:.1f}м).",
                    status_code=400,
                )

        # 4. Authoritative Server Time & Date
        server_now = current_time_in_school_timezone(school.timezone)
        today = server_now.date()

        # 5. Check if check-in exists today
        daily_res = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher.id,
                DailyAttendance.date == today,
            )
        )
        daily = daily_res.scalar_one_or_none()
        if not daily or daily.check_in_time is None:
            raise AppException(
                code=ErrorCode.NO_CHECK_IN_FOUND,
                message="Жумуштан кетүүнү белгилөөдөн мурда келүү (Check-in) белгилениши керек.",
                status_code=400,
            )

        if daily.check_out_time is not None:
            raise AppException(
                code=ErrorCode.ALREADY_CHECKED_OUT,
                message=f"Сиз бүгүн саат {daily.check_out_time.strftime('%H:%M')}де кеткениңизди белгилегенсиз.",
                status_code=400,
            )

        # 6. Calculate worked minutes
        check_in_dt = to_school_timezone(daily.check_in_time, school.timezone)
        worked_seconds = (server_now - check_in_dt).total_seconds()
        worked_minutes = max(0, int(worked_seconds / 60))

        # 7. Record AttendanceEvent (Check-out)
        event = AttendanceEvent(
            teacher_id=teacher.id,
            school_id=school.id,
            event_type=AttendanceEventType.CHECK_OUT,
            event_time=server_now,
            status=daily.status,
            late_minutes=0,
            distance_meters=distance,
            location_accuracy_meters=payload.accuracy,
            location_verified=True,
            qr_verified=True,
            device_info=payload.device_info,
        )
        db.add(event)

        # 8. Update DailyAttendance
        daily.check_out_time = server_now
        daily.worked_minutes = worked_minutes
        await db.commit()
        await db.refresh(daily)

        return DailyAttendanceRead(
            id=daily.id,
            teacher_id=daily.teacher_id,
            school_id=daily.school_id,
            date=daily.date,
            check_in_time=daily.check_in_time,
            check_out_time=daily.check_out_time,
            status=daily.status,
            late_minutes=daily.late_minutes,
            worked_minutes=daily.worked_minutes,
            is_manually_corrected=daily.is_manually_corrected,
            correction_reason=daily.correction_reason,
            teacher_name=user.full_name,
            employee_code=teacher.employee_code,
        )

    @staticmethod
    async def get_today_status(
        db: AsyncSession, teacher: Teacher, school: School
    ) -> TodayStatusResponse:
        server_now = current_time_in_school_timezone(school.timezone)
        today = server_now.date()

        schedule = await ScheduleService.resolve_schedule_for_date(
            db=db,
            school_id=school.id,
            teacher_id=teacher.id,
            target_date=today,
        )

        daily_res = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher.id,
                DailyAttendance.date == today,
            )
        )
        daily = daily_res.scalar_one_or_none()

        return TodayStatusResponse(
            date=today,
            has_checked_in=daily is not None and daily.check_in_time is not None,
            has_checked_out=daily is not None and daily.check_out_time is not None,
            check_in_time=daily.check_in_time if daily else None,
            check_out_time=daily.check_out_time if daily else None,
            status=daily.status if daily else None,
            late_minutes=daily.late_minutes if daily else 0,
            worked_minutes=daily.worked_minutes if daily else 0,
            scheduled_start=schedule.start_time if schedule else school.default_start_time,
            scheduled_end=schedule.end_time if schedule else school.default_end_time,
            is_day_off=schedule.is_day_off if schedule else False,
        )

    @staticmethod
    async def get_teacher_history(
        db: AsyncSession,
        teacher_id: str,
        year: Optional[int] = None,
        month: Optional[int] = None,
    ) -> List[DailyAttendanceRead]:
        query = (
            select(DailyAttendance)
            .where(DailyAttendance.teacher_id == teacher_id)
            .order_by(DailyAttendance.date.desc())
        )

        result = await db.execute(query)
        records = result.scalars().all()

        if year and month:
            records = [
                r for r in records if r.date.year == year and r.date.month == month
            ]

        return [
            DailyAttendanceRead(
                id=r.id,
                teacher_id=r.teacher_id,
                school_id=r.school_id,
                date=r.date,
                check_in_time=r.check_in_time,
                check_out_time=r.check_out_time,
                status=r.status,
                late_minutes=r.late_minutes,
                worked_minutes=r.worked_minutes,
                is_manually_corrected=r.is_manually_corrected,
                correction_reason=r.correction_reason,
            )
            for r in records
        ]

    @staticmethod
    async def get_admin_today_dashboard(
        db: AsyncSession, school_id: str, target_date: Optional[date] = None
    ) -> AdminDashboardSummary:
        school_res = await db.execute(select(School).where(School.id == school_id))
        school = school_res.scalar_one()
        query_date = target_date or today_date_in_school_timezone(school.timezone)

        # Get all active teachers in school
        teachers_res = await db.execute(
            select(Teacher)
            .join(User, Teacher.user_id == User.id)
            .options(selectinload(Teacher.user))
            .where(
                Teacher.school_id == school_id,
                Teacher.is_active == True,  # noqa: E712
            )
        )
        teachers = teachers_res.scalars().all()
        total_teachers = len(teachers)

        # Get attendance records for this date
        records_res = await db.execute(
            select(DailyAttendance)
            .join(Teacher, DailyAttendance.teacher_id == Teacher.id)
            .join(User, Teacher.user_id == User.id)
            .options(
                selectinload(DailyAttendance.teacher).selectinload(Teacher.user)
            )
            .where(
                DailyAttendance.school_id == school_id,
                DailyAttendance.date == query_date,
            )
        )
        daily_records = records_res.scalars().all()
        records_by_teacher_id = {r.teacher_id: r for r in daily_records}

        checked_in_count = 0
        on_time_count = 0
        late_count = 0

        read_records: List[DailyAttendanceRead] = []
        for t in teachers:
            record = records_by_teacher_id.get(t.id)
            if record and record.check_in_time:
                checked_in_count += 1
                if record.status == AttendanceStatus.ON_TIME:
                    on_time_count += 1
                elif record.status == AttendanceStatus.LATE:
                    late_count += 1

                read_records.append(
                    DailyAttendanceRead(
                        id=record.id,
                        teacher_id=t.id,
                        school_id=school_id,
                        date=query_date,
                        check_in_time=record.check_in_time,
                        check_out_time=record.check_out_time,
                        status=record.status,
                        late_minutes=record.late_minutes,
                        worked_minutes=record.worked_minutes,
                        is_manually_corrected=record.is_manually_corrected,
                        correction_reason=record.correction_reason,
                        teacher_name=t.user.full_name,
                        employee_code=t.employee_code,
                    )
                )
            else:
                # Not checked in yet
                read_records.append(
                    DailyAttendanceRead(
                        id=f"virtual-{t.id}",
                        teacher_id=t.id,
                        school_id=school_id,
                        date=query_date,
                        check_in_time=None,
                        check_out_time=None,
                        status=AttendanceStatus.ABSENT,
                        late_minutes=0,
                        worked_minutes=0,
                        is_manually_corrected=False,
                        correction_reason=None,
                        teacher_name=t.user.full_name,
                        employee_code=t.employee_code,
                    )
                )

        not_checked_in_count = total_teachers - checked_in_count

        return AdminDashboardSummary(
            total_teachers=total_teachers,
            checked_in_count=checked_in_count,
            on_time_count=on_time_count,
            late_count=late_count,
            not_checked_in_count=not_checked_in_count,
            date=query_date,
            records=read_records,
        )

    @staticmethod
    async def manual_correction(
        db: AsyncSession, admin_user: User, payload: ManualCorrectionRequest
    ) -> DailyAttendanceRead:
        teacher_res = await db.execute(
            select(Teacher)
            .where(Teacher.id == payload.teacher_id)
            .options(selectinload(Teacher.user))
        )
        teacher = teacher_res.scalar_one_or_none()
        if not teacher:
            raise AppException(
                code=ErrorCode.TEACHER_NOT_FOUND,
                message="Мугалим табылган жок",
                status_code=404,
            )

        daily_res = await db.execute(
            select(DailyAttendance).where(
                DailyAttendance.teacher_id == payload.teacher_id,
                DailyAttendance.date == payload.target_date,
            )
        )
        daily = daily_res.scalar_one_or_none()

        old_values = {}
        if daily:
            old_values = {
                "status": daily.status.value,
                "check_in_time": str(daily.check_in_time) if daily.check_in_time else None,
                "check_out_time": str(daily.check_out_time) if daily.check_out_time else None,
            }
            daily.status = payload.status
            if payload.check_in_time is not None:
                daily.check_in_time = payload.check_in_time
            if payload.check_out_time is not None:
                daily.check_out_time = payload.check_out_time
            daily.is_manually_corrected = True
            daily.correction_reason = payload.reason
            daily.corrected_by_id = admin_user.id
        else:
            daily = DailyAttendance(
                teacher_id=teacher.id,
                school_id=teacher.school_id,
                date=payload.target_date,
                check_in_time=payload.check_in_time,
                check_out_time=payload.check_out_time,
                status=payload.status,
                is_manually_corrected=True,
                correction_reason=payload.reason,
                corrected_by_id=admin_user.id,
            )
            db.add(daily)

        # AGENTS.md #18: Audit log for manual correction
        audit = AuditLog(
            school_id=teacher.school_id,
            user_id=admin_user.id,
            action="MANUAL_ATTENDANCE_CORRECTION",
            entity_name="daily_attendance",
            entity_id=daily.id,
            old_values=json.dumps(old_values),
            new_values=json.dumps({
                "status": payload.status.value,
                "reason": payload.reason,
                "target_date": str(payload.target_date),
            }),
        )
        db.add(audit)
        await db.commit()
        await db.refresh(daily)

        return DailyAttendanceRead(
            id=daily.id,
            teacher_id=daily.teacher_id,
            school_id=daily.school_id,
            date=daily.date,
            check_in_time=daily.check_in_time,
            check_out_time=daily.check_out_time,
            status=daily.status,
            late_minutes=daily.late_minutes,
            worked_minutes=daily.worked_minutes,
            is_manually_corrected=daily.is_manually_corrected,
            correction_reason=daily.correction_reason,
            teacher_name=teacher.user.full_name,
            employee_code=teacher.employee_code,
        )
