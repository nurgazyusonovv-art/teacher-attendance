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
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User
from app.schemas.teacher import (
    TeacherCreate,
    TeacherListResponse,
    TeacherRead,
    TeacherUpdate,
)
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
    school_id = await get_user_school_id(db, admin_user)
    items, total = await TeacherService.list_teachers(
        db=db,
        school_id=school_id,
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
        payload.school_id = await get_user_school_id(db, admin_user)
    await ensure_school_access(db, admin_user, payload.school_id)
    return await TeacherService.create_teacher(
        db, payload, actor_user_id=admin_user.id
    )


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
    await ensure_teacher_access(db, admin_user, teacher_id)
    return await TeacherService.get_teacher_by_id(db, teacher_id)


@router.patch("/{teacher_id}", response_model=TeacherRead, summary="Мугалимдин маалыматын өзгөртүү (Админ)")
async def update_teacher(
    teacher_id: str,
    payload: TeacherUpdate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_teacher_access(db, admin_user, teacher_id)
    return await TeacherService.update_teacher(
        db, teacher_id, payload, actor_user_id=admin_user.id
    )


@router.delete("/{teacher_id}", summary="Мугалимдин каттоосун өчүрүү же деактивациялоо (Админ)")
async def delete_teacher(
    teacher_id: str,
    hard_delete: bool = Query(False, description="Базадан толук өчүрүү"),
    confirmation: Optional[str] = Query(
        None,
        description=(
            "Катышуу тарыхы бар мугалимди толук өчүрүү үчүн талап кылынган "
            "ырастоо сөзү: «DELETE ATTENDANCE HISTORY»"
        ),
    ),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_teacher_access(db, admin_user, teacher_id)
    if hard_delete:
        await TeacherService.delete_teacher(
            db, teacher_id, actor_user_id=admin_user.id, confirmation=confirmation
        )
        return {"success": True, "message": "Мугалим базадан толук өчүрүлдү"}
    return await TeacherService.deactivate_teacher(
        db, teacher_id, actor_user_id=admin_user.id
    )
