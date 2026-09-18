from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    ensure_teacher_access,
    get_current_active_admin,
    get_current_active_teacher,
    get_current_user,
    get_user_school_id,
)
from app.db.session import get_db
from app.core.errors import AppException, ErrorCode
from app.models.enums import UserRole
from app.models.teacher import Teacher
from app.models.lesson_delay import LessonDelay
from app.models.user import User
from app.schemas.attendance import (
    AdminDashboardSummary,
    AttendanceScanRequest,
    DailyAttendanceRead,
    ManualCorrectionRequest,
    TodayStatusResponse,
    AttendanceResetRequest,
)
from app.services.absence_service import AbsenceService
from app.services.attendance_reset_service import AttendanceResetService
from app.schemas.lesson_delay import (
    LessonDelayCreate,
    LessonDelayRead,
)
from app.services.attendance_service import AttendanceService
from app.services.audit_service import AuditService
from app.services.lesson_delay_service import LessonDelayService
from app.services.school_service import SchoolService
from app.services.rate_limit_service import RateLimitService
from sqlalchemy import select

router = APIRouter()

_SUSPICIOUS_SCAN_CODES = {
    ErrorCode.QR_INVALID,
    ErrorCode.QR_DISABLED,
    ErrorCode.QR_EXPIRED,
    ErrorCode.QR_WRONG_SCHOOL,
    ErrorCode.LOCATION_OUTSIDE_SCHOOL,
    ErrorCode.LOCATION_ACCURACY_TOO_LOW,
    ErrorCode.RATE_LIMITED,
}


async def _record_rejected_scan(
    db: AsyncSession,
    teacher: Teacher,
    payload: AttendanceScanRequest,
    error: AppException,
) -> None:
    if error.code not in _SUSPICIOUS_SCAN_CODES:
        return
    AuditService.add(
        db,
        school_id=teacher.school_id,
        user_id=teacher.user_id,
        action="ATTENDANCE_SCAN_REJECTED",
        entity_name="teacher",
        entity_id=teacher.id,
        new_values={
            "error_code": error.code.value,
            "requested_school_id": payload.school_id,
            "location_accuracy_meters": payload.accuracy,
        },
    )
    await db.commit()


@router.post("/check-in", response_model=DailyAttendanceRead, summary="Келүү убактысын каттоо (Check-in)")
async def check_in(
    payload: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    try:
        await RateLimitService.enforce_attendance_limit(db, current_teacher.user_id)
        return await AttendanceService.register_check_in(
            db=db,
            teacher=current_teacher,
            user=current_teacher.user,
            payload=payload,
        )
    except AppException as error:
        await _record_rejected_scan(db, current_teacher, payload, error)
        raise


@router.post("/check-out", response_model=DailyAttendanceRead, summary="Кетүү убактысын каттоо (Check-out)")
async def check_out(
    payload: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    try:
        await RateLimitService.enforce_attendance_limit(db, current_teacher.user_id)
        return await AttendanceService.register_check_out(
            db=db,
            teacher=current_teacher,
            user=current_teacher.user,
            payload=payload,
        )
    except AppException as error:
        await _record_rejected_scan(db, current_teacher, payload, error)
        raise


@router.get("/today", response_model=TodayStatusResponse, summary="Бүгүнкү каттоо статусун алуу")
async def get_today_status(
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    school = await SchoolService.get_school_by_id(
        db, current_teacher.school_id
    )
    return await AttendanceService.get_today_status(
        db=db,
        teacher=current_teacher,
        school=school,
    )


@router.get("/my-history", response_model=List[DailyAttendanceRead], summary="Өзүнүн катышуу тарыхын көрүү")
async def get_my_history(
    year: Optional[int] = Query(None, description="Жыл боюнча чыпка"),
    month: Optional[int] = Query(None, description="Ай боюнча чыпка (1-12)"),
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    return await AttendanceService.get_teacher_history(
        db=db,
        teacher_id=current_teacher.id,
        year=year,
        month=month,
    )


@router.get("/teacher/{teacher_id}/history", response_model=List[DailyAttendanceRead], summary="Мугалимдин катышуу тарыхын алуу (Админ)")
async def get_teacher_history_for_admin(
    teacher_id: str,
    year: Optional[int] = Query(None, description="Жыл боюнча чыпка"),
    month: Optional[int] = Query(None, description="Ай боюнча чыпка (1-12)"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    # Absence finalization is a write and belongs to the scheduled job
    # (scripts/finalize_absences.py), never to a read endpoint.
    await ensure_teacher_access(db, admin_user, teacher_id)
    return await AttendanceService.get_teacher_history(
        db=db,
        teacher_id=teacher_id,
        year=year,
        month=month,
    )


@router.get("/dashboard/today", response_model=AdminDashboardSummary, summary="Бүгүнкү катышуу дашборду (Админ)")
async def get_today_dashboard(
    target_date: Optional[date] = Query(None, description="Кароо күнү (демейки: бүгүн)"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    return await AttendanceService.get_admin_today_dashboard(
        db=db,
        school_id=school_id,
        target_date=target_date,
    )


@router.post("/admin/finalize-absences", summary="Иш күндөрдөгү келбөөнү белгилөө (Админ)")
async def finalize_absences(
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    count = await AbsenceService.process_workdays_from(db, school_id, start_date, end_date)
    return {"created_or_updated": count, "start_date": start_date, "end_date": end_date}


@router.post("/admin/catch-up-absences", summary="Иштелбеген күндөрдү автоматтык белгилөө (Админ)")
async def catch_up_absences(
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    """Manual trigger for the same pass the scheduled job runs. Idempotent."""
    school_id = await get_user_school_id(db, admin_user)
    created = await AbsenceService.catch_up(db, school_id)
    return {"created_or_updated": created}


@router.post("/admin/reset", summary="Мектептин катышуу тест маалыматтарын тазалоо (Админ)")
async def reset_attendance(
    payload: AttendanceResetRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    return await AttendanceResetService.reset(db, school_id, admin_user.id, payload.confirmation)


@router.post("/manual-correction", response_model=DailyAttendanceRead, summary="Катышууну кол менен оңдоо (Админ)")
async def manual_correction(
    payload: ManualCorrectionRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_teacher_access(db, admin_user, payload.teacher_id)
    return await AttendanceService.manual_correction(
        db=db,
        admin_user=admin_user,
        payload=payload,
    )


# --- Lesson Delays Endpoints ---

@router.post("/lesson-delays", response_model=LessonDelayRead, summary="Сабакка кечигүүнү каттоо (Админ)")
async def add_lesson_delay(
    payload: LessonDelayCreate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_teacher_access(db, admin_user, payload.teacher_id)
    return await LessonDelayService.create_lesson_delay(
        db=db,
        payload=payload,
        recorded_by_user_id=admin_user.id,
    )


@router.get("/lesson-delays", response_model=List[LessonDelayRead], summary="Сабактардагы кечигүүлөрдү алуу")
async def get_lesson_delays(
    teacher_id: Optional[str] = Query(None, description="Мугалимдин IDси"),
    target_date: Optional[date] = Query(None, description="Күн боюнча чыпка"),
    year: Optional[int] = Query(None, description="Жыл"),
    month: Optional[int] = Query(None, description="Ай (1-12)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_teacher_id = teacher_id
    if current_user.role == UserRole.TEACHER:
        if not current_user.teacher_profile:
            return []
        target_teacher_id = current_user.teacher_profile.id
    elif target_teacher_id:
        await ensure_teacher_access(db, current_user, target_teacher_id)

    if not target_teacher_id:
        return []

    return await LessonDelayService.get_lesson_delays_for_teacher(
        db=db,
        teacher_id=target_teacher_id,
        target_date=target_date,
        year=year,
        month=month,
    )


@router.delete("/lesson-delays/{delay_id}", summary="Сабак кечигүүсүн өчүрүү (Админ)")
async def delete_lesson_delay(
    delay_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    result = await db.execute(select(LessonDelay).where(LessonDelay.id == delay_id))
    delay = result.scalar_one_or_none()
    if delay:
        await ensure_teacher_access(db, admin_user, delay.teacher_id)
    success = await LessonDelayService.delete_lesson_delay(
        db, delay_id, actor_user_id=admin_user.id
    )
    return {"success": success, "message": "Сабак кечигүүсү өчүрүлдү" if success else "Табылган жок"}
