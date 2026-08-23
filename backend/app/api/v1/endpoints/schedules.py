from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin, get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.schedule import (
    ScheduleCreate,
    ScheduleRead,
    ScheduleUpdate,
    WeeklyScheduleResponse,
)
from app.services.schedule_service import ScheduleService
from app.services.school_service import SchoolService

router = APIRouter()


@router.get("", response_model=WeeklyScheduleResponse, summary="Жумалык иш графиктерин алуу")
async def get_schedules(
    school_id: Optional[str] = None,
    teacher_id: Optional[str] = Query(None, description="Конкреттүү мугалимдин IDси"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_school_id = school_id
    if not target_school_id and current_user.teacher_profile:
        target_school_id = current_user.teacher_profile.school_id
    if not target_school_id:
        school = await SchoolService.get_first_active_school(db)
        target_school_id = school.id

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
        school = await SchoolService.get_first_active_school(db)
        payload.school_id = school.id
    schedule = await ScheduleService.create_or_update_schedule(db, payload)
    return ScheduleRead.model_validate(schedule)


@router.patch("/{schedule_id}", response_model=ScheduleRead, summary="Иш графигин өзгөртүү (Админ)")
async def update_schedule(
    schedule_id: str,
    payload: ScheduleUpdate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    schedule = await ScheduleService.update_schedule(db, schedule_id, payload)
    return ScheduleRead.model_validate(schedule)


@router.delete("/{schedule_id}", summary="Иш графигин өчүрүү (Админ)")
async def delete_schedule(
    schedule_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ScheduleService.delete_schedule(db, schedule_id)
    return {"message": "Иш графиги ийгиликтүү өчүрүлдү"}
