from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    ensure_school_access,
    ensure_teacher_access,
    get_current_active_admin,
    get_current_user,
    get_user_school_id,
)
from app.models.enums import UserRole
from app.models.schedule import WorkSchedule
from app.core.errors import AppException, ErrorCode
from sqlalchemy import select
from app.db.session import get_db
from app.models.user import User
from app.schemas.schedule import (
    ScheduleCreate,
    ScheduleRead,
    ScheduleUpdate,
    WeeklyScheduleResponse,
)
from app.services.schedule_service import ScheduleService

router = APIRouter()


@router.get("", response_model=WeeklyScheduleResponse, summary="Жумалык иш графиктерин алуу")
async def get_schedules(
    school_id: Optional[str] = None,
    teacher_id: Optional[str] = Query(None, description="Конкреттүү мугалимдин IDси"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_school_id = school_id or await get_user_school_id(db, current_user)
    await ensure_school_access(db, current_user, target_school_id)
    if current_user.role == UserRole.TEACHER:
        teacher_id = current_user.teacher_profile.id
    elif teacher_id:
        await ensure_teacher_access(db, current_user, teacher_id)

    schedules = await ScheduleService.get_schedules_for_school(
        db, target_school_id, teacher_id
    )
    return WeeklyScheduleResponse(
        school_id=target_school_id,
        teacher_id=teacher_id,
        schedules=[ScheduleRead.model_validate(s) for s in schedules],
    )


@router.post("", response_model=ScheduleRead, summary="Иш графигин түзүү / жаңыртуу (Админ)")
async def create_or_update_schedule(
    payload: ScheduleCreate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    if not payload.school_id:
        payload.school_id = await get_user_school_id(db, admin_user)
    await ensure_school_access(db, admin_user, payload.school_id)
    if payload.teacher_id:
        teacher = await ensure_teacher_access(db, admin_user, payload.teacher_id)
        if teacher.school_id != payload.school_id:
            raise AppException(
                ErrorCode.VALIDATION_ERROR,
                "Мугалим менен график бир мектепке таандык болушу керек.",
                400,
            )
    schedule = await ScheduleService.create_or_update_schedule(
        db, payload, actor_user_id=admin_user.id
    )
    return ScheduleRead.model_validate(schedule)


@router.patch("/{schedule_id}", response_model=ScheduleRead, summary="Иш графигин өзгөртүү (Админ)")
async def update_schedule(
    schedule_id: str,
    payload: ScheduleUpdate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    result = await db.execute(select(WorkSchedule).where(WorkSchedule.id == schedule_id))
    existing = result.scalar_one_or_none()
    if not existing:
        raise AppException(ErrorCode.NOT_FOUND, "График табылган жок", 404)
    await ensure_school_access(db, admin_user, existing.school_id)
    schedule = await ScheduleService.update_schedule(
        db, schedule_id, payload, actor_user_id=admin_user.id
    )
    return ScheduleRead.model_validate(schedule)


@router.delete("/{schedule_id}", summary="Иш графигин өчүрүү (Админ)")
async def delete_schedule(
    schedule_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    result = await db.execute(select(WorkSchedule).where(WorkSchedule.id == schedule_id))
    existing = result.scalar_one_or_none()
    if not existing:
        raise AppException(ErrorCode.NOT_FOUND, "График табылган жок", 404)
    await ensure_school_access(db, admin_user, existing.school_id)
    await ScheduleService.delete_schedule(
        db, schedule_id, actor_user_id=admin_user.id
    )
    return {"message": "Иш графиги ийгиликтүү өчүрүлдү"}
