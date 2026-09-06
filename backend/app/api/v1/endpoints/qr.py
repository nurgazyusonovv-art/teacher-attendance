from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ensure_school_access, get_current_active_admin, get_user_school_id
from app.db.session import get_db
from app.models.user import User
from app.schemas.qr import QrPayloadResponse
from app.services.qr_service import QrService

router = APIRouter()


@router.get("/current", response_model=QrPayloadResponse, summary="Учурдагы мектептин QR маалыматын алуу (Админ)")
async def get_current_school_qr(
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    await ensure_school_access(db, admin_user, school_id)
    return await QrService.get_active_school_qr(db, school_id)


@router.get("/{school_id}", response_model=QrPayloadResponse, summary="Мектептин QR кодун алуу (Админ)")
async def get_school_qr(
    school_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_school_access(db, admin_user, school_id)
    return await QrService.get_active_school_qr(db, school_id)


@router.post("/{school_id}/rotate", response_model=QrPayloadResponse, summary="Мектептин QR кодун жаңылоо/ротация (Админ)")
async def rotate_school_qr(
    school_id: str,
    description: Optional[str] = Query(None, description="Ротациянын себеби же сүрөттөмөсү"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    await ensure_school_access(db, admin_user, school_id)
    return await QrService.rotate_school_qr(
        db, school_id, description, actor_user_id=admin_user.id
    )
