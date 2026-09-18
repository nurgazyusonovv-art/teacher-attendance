from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import (
    ensure_teacher_access,
    get_current_active_admin,
    get_current_user,
    get_user_school_id,
)
from app.db.session import get_db
from app.models.enums import DeviceStatus
from app.models.user import User
from app.schemas.device import AdminDeviceRead, DeviceRead, DeviceRegisterRequest
from app.services.device_service import DeviceService

router = APIRouter()


@router.post("/register", response_model=DeviceRead, summary="Түзмөктү жана Push-билдирүү токенин каттоо")
async def register_device(
    payload: DeviceRegisterRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Registers the caller's device.

    The first device is approved immediately; any later one is stored as
    PENDING until an administrator approves it.
    """
    device = await DeviceService.register(db, current_user, payload)
    return DeviceRead.model_validate(device)


@router.get("/me", response_model=List[DeviceRead], summary="Өз түзмөктөрүмдү көрүү")
async def list_my_devices(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from sqlalchemy import select

    from app.models.device import Device

    rows = await db.execute(
        select(Device)
        .where(Device.user_id == current_user.id)
        .order_by(Device.created_at.desc())
    )
    return [DeviceRead.model_validate(device) for device in rows.scalars().all()]


@router.get("", response_model=List[AdminDeviceRead], summary="Мектептин түзмөктөрү (Админ)")
async def list_school_devices(
    teacher_id: Optional[str] = Query(None, description="Мугалим боюнча чыпка"),
    status: Optional[DeviceStatus] = Query(None, description="Абалы боюнча чыпка"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    if teacher_id:
        await ensure_teacher_access(db, admin_user, teacher_id)
    rows = await DeviceService.list_for_school(db, school_id, teacher_id, status)
    return [
        AdminDeviceRead(
            **DeviceRead.model_validate(device).model_dump(),
            teacher_name=user.full_name,
            username=user.username,
        )
        for device, user in rows
    ]


@router.post("/{device_id}/approve", response_model=DeviceRead, summary="Түзмөктү ырастоо (Админ)")
async def approve_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    """Approves a device and revokes the teacher's previous one."""
    school_id = await get_user_school_id(db, admin_user)
    device = await DeviceService.approve(db, device_id, school_id, admin_user)
    return DeviceRead.model_validate(device)


@router.post("/{device_id}/revoke", response_model=DeviceRead, summary="Түзмөктү жокко чыгаруу (Админ)")
async def revoke_device(
    device_id: str,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = await get_user_school_id(db, admin_user)
    device = await DeviceService.revoke(db, device_id, school_id, admin_user)
    return DeviceRead.model_validate(device)
