from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin, get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.school import SchoolRead, SchoolUpdate
from app.services.school_service import SchoolService

router = APIRouter()


@router.get("/current", response_model=SchoolRead, summary="Учурдагы мектептин жөндөөлөрүн алуу")
async def get_current_school(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Кирген колдонуучу таандык болгон же негизги мектепти кайтарат."""
    if current_user.teacher_profile and current_user.teacher_profile.school_id:
        return await SchoolService.get_school_by_id(
            db, current_user.teacher_profile.school_id
        )
    return await SchoolService.get_first_active_school(db)


@router.get("/{school_id}", response_model=SchoolRead, summary="Мектептин жөндөөлөрүн алуу")
async def get_school(
    school_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await SchoolService.get_school_by_id(db, school_id)


@router.patch("/{school_id}", response_model=SchoolRead, summary="Мектептин жөндөөлөрүн өзгөртүү (Админ)")
async def update_school(
    school_id: str,
    payload: SchoolUpdate,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await SchoolService.update_school(db, school_id, payload)
