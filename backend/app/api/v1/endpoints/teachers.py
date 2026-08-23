from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin, get_current_user
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.teacher import (
    TeacherCreate,
    TeacherListResponse,
    TeacherRead,
    TeacherUpdate,
)
from app.services.school_service import SchoolService
from app.services.teacher_service import TeacherService

router = APIRouter()


@router.get("", response_model=TeacherListResponse, summary="Мугалимдердин тизмесин алуу (Админ)")
async def list_teachers(
    search: Optional[str] = Query(None, description="Аты-жөнү же коду боюнча издөө"),
    is_active: Optional[bool] = Query(None, description="Активдүүлүк боюнча чыпка"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school = await SchoolService.get_first_active_school(db)
    items, total = await TeacherService.list_teachers(
        db=db,
        school_id=school.id,
        search=search,
        is_active=is_active,
        skip=skip,
        limit=limit,
    )
    return TeacherListResponse(items=items, total=total)


@router.post("", response_model=TeacherRead, summary="Жаңы мугалим кошуу (Админ)")
async def create_teacher(
    payload: TeacherCreate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    if not payload.school_id:
        school = await SchoolService.get_first_active_school(db)
        payload.school_id = school.id
    return await TeacherService.create_teacher(db, payload)


@router.get("/me", response_model=Optional[TeacherRead], summary="Кирген мугалимдин профилин алуу")
async def get_my_teacher_profile(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.TEACHER or not current_user.teacher_profile:
        return None
    return await TeacherService.get_teacher_by_id(db, current_user.teacher_profile.id)


@router.get("/{teacher_id}", response_model=TeacherRead, summary="Мугалимдин маалыматын алуу (Админ)")
async def get_teacher(
    teacher_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await TeacherService.get_teacher_by_id(db, teacher_id)


@router.patch("/{teacher_id}", response_model=TeacherRead, summary="Мугалимдин маалыматын өзгөртүү (Админ)")
async def update_teacher(
    teacher_id: str,
    payload: TeacherUpdate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await TeacherService.update_teacher(db, teacher_id, payload)


@router.delete("/{teacher_id}", response_model=TeacherRead, summary="Мугалимдин каттоосун өчүрүү/деактивация (Админ)")
async def deactivate_teacher(
    teacher_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await TeacherService.deactivate_teacher(db, teacher_id)
