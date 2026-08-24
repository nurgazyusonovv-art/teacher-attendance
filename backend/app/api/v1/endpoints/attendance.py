from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin, get_current_active_teacher, get_current_user
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.teacher import Teacher
from app.models.user import User
from app.schemas.attendance import (
    AdminDashboardSummary,
    AttendanceScanRequest,
    DailyAttendanceRead,
    ManualCorrectionRequest,
    TodayStatusResponse,
)
from app.schemas.lesson_delay import (
    LessonDelayCreate,
    LessonDelayListResponse,
    LessonDelayRead,
)
from app.services.attendance_service import AttendanceService
from app.services.lesson_delay_service import LessonDelayService
from app.services.school_service import SchoolService

router = APIRouter()


@router.post("/check-in", response_model=DailyAttendanceRead, summary="Келүү убактысын каттоо (Check-in)")
async def check_in(
    payload: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    return await AttendanceService.register_check_in(
        db=db,
        teacher=current_teacher,
        user=current_teacher.user,
        payload=payload,
    )


@router.post("/check-out", response_model=DailyAttendanceRead, summary="Кетүү убактысын каттоо (Check-out)")
async def check_out(
    payload: AttendanceScanRequest,
    db: AsyncSession = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_active_teacher),
):
    return await AttendanceService.register_check_out(
        db=db,
        teacher=current_teacher,
        user=current_teacher.user,
        payload=payload,
    )


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
    school_id = (
        admin_user.teacher_profile.school_id
        if admin_user.teacher_profile
        else (await SchoolService.get_first_active_school(db)).id
    )
    return await AttendanceService.get_admin_today_dashboard(
        db=db,
        school_id=school_id,
        target_date=target_date,
    )


@router.post("/manual-correction", response_model=DailyAttendanceRead, summary="Катышууну кол менен оңдоо (Админ)")
async def manual_correction(
    payload: ManualCorrectionRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
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
    success = await LessonDelayService.delete_lesson_delay(db, delay_id)
    return {"success": success, "message": "Сабак кечигүүсү өчүрүлдү" if success else "Табылган жок"}
