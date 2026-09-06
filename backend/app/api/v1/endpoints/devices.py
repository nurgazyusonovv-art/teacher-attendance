from fastapi import APIRouter, Depends
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.device import Device
from app.models.user import User
from app.schemas.device import DeviceRead, DeviceRegisterRequest

router = APIRouter()


@router.post("/register", response_model=DeviceRead, summary="Түзмөктү жана Push-билдирүү токенин каттоо")
async def register_device(
    payload: DeviceRegisterRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if device already registered for this user
    result = await db.execute(
        select(Device).where(
            Device.user_id == current_user.id,
            Device.device_id == payload.device_id,
        )
    )
    device = result.scalar_one_or_none()

    if device:
        device.platform = payload.platform
        if payload.fcm_token:
            device.fcm_token = payload.fcm_token
        device.is_active = True
        device.last_seen_at = datetime.now(timezone.utc)
    else:
        device = Device(
            user_id=current_user.id,
            device_id=payload.device_id,
            platform=payload.platform,
            fcm_token=payload.fcm_token,
            is_active=True,
        )
        db.add(device)

    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # A concurrent registration created the same user/device pair.
        device = (
            await db.execute(
                select(Device).where(
                    Device.user_id == current_user.id,
                    Device.device_id == payload.device_id,
                )
            )
        ).scalar_one()
        device.platform = payload.platform
        if payload.fcm_token:
            device.fcm_token = payload.fcm_token
        device.is_active = True
        device.last_seen_at = datetime.now(timezone.utc)
        await db.commit()
    await db.refresh(device)
    return DeviceRead.model_validate(device)
