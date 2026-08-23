from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin, get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.qr import QrPayloadResponse
from app.services.qr_service import QrService
from app.services.school_service import SchoolService

router = APIRouter()


@router.get("/current", response_model=QrPayloadResponse, summary="Учурдагы мектептин QR маалыматын алуу (Админ)")
async def get_current_school_qr(
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = None
    if admin_user.teacher_profile:
        school_id = admin_user.teacher_profile.school_id
    if not school_id:
        school = await SchoolService.get_first_active_school(db)
        school_id = school.id
    return await QrService.get_active_school_qr(db, school_id)


@router.get("/{school_id}", response_model=QrPayloadResponse, summary="Мектептин QR кодун алуу (Админ)")
async def get_school_qr(
    school_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await QrService.get_active_school_qr(db, school_id)


@router.post("/{school_id}/rotate", response_model=QrPayloadResponse, summary="Мектептин QR кодун жаңылоо/ротация (Админ)")
async def rotate_school_qr(
    school_id: str,
    description: Optional[str] = Query(None, description="Ротациянын себеби же сүрөттөмөсү"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    return await QrService.rotate_school_qr(db, school_id, description)
