"""Device binding: one teacher, one approved device.

PROJECT.md §10 lists a registered device as an attendance security layer. A
teacher's first device is trusted on registration — otherwise nobody could ever
record attendance — and every device after it waits for an administrator, so a
stolen password alone is not enough to scan from an attacker's phone.

Enforcement is per school (`School.device_binding_enabled`) and off by default,
because app versions already in the field send no device id.
"""

from datetime import datetime, timezone
from typing import List, Optional, Tuple

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppException, ErrorCode
from app.models.device import Device
from app.models.enums import DeviceStatus
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.schemas.device import DeviceRegisterRequest
from app.services.audit_service import AuditService


class DeviceService:
    @staticmethod
    def _apply_status(device: Device, status: DeviceStatus) -> None:
        device.status = status
        device.is_active = status == DeviceStatus.APPROVED

    @staticmethod
    async def _approved_devices(
        db: AsyncSession, user_id: str, exclude_id: Optional[str] = None
    ) -> List[Device]:
        query = select(Device).where(
            Device.user_id == user_id,
            Device.status == DeviceStatus.APPROVED,
        )
        if exclude_id:
            query = query.where(Device.id != exclude_id)
        return list((await db.execute(query)).scalars().all())

    @classmethod
    async def register(
        cls,
        db: AsyncSession,
        user: User,
        payload: DeviceRegisterRequest,
        *,
        retry_on_conflict: bool = True,
    ) -> Device:
        """Registers or refreshes a device and returns its approval state."""
        existing = (
            await db.execute(
                select(Device).where(
                    Device.user_id == user.id,
                    Device.device_id == payload.device_id,
                )
            )
        ).scalar_one_or_none()

        now = datetime.now(timezone.utc)
        school_id = user.teacher_profile.school_id if user.teacher_profile else user.school_id

        if existing is not None:
            existing.platform = payload.platform
            if payload.fcm_token:
                existing.fcm_token = payload.fcm_token
            existing.last_seen_at = now
            # A revoked device is not resurrected by re-registering it; an
            # administrator has to approve it again.
            await db.commit()
            await db.refresh(existing)
            return existing

        already_approved = await cls._approved_devices(db, user.id)
        status = (
            DeviceStatus.PENDING if already_approved else DeviceStatus.APPROVED
        )
        device = Device(
            user_id=user.id,
            device_id=payload.device_id,
            platform=payload.platform,
            fcm_token=payload.fcm_token,
            last_seen_at=now,
            approved_at=now if status == DeviceStatus.APPROVED else None,
        )
        cls._apply_status(device, status)
        db.add(device)

        AuditService.add(
            db,
            school_id=school_id,
            user_id=user.id,
            action=(
                "DEVICE_AUTO_APPROVED"
                if status == DeviceStatus.APPROVED
                else "DEVICE_PENDING_APPROVAL"
            ),
            entity_name="device",
            entity_id=device.id,
            new_values={"device_id": payload.device_id, "platform": payload.platform.value},
        )

        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            if not retry_on_conflict:
                raise
            # A concurrent registration created the same user/device pair.
            return await cls.register(
                db, user, payload, retry_on_conflict=False
            )
        await db.refresh(device)
        return device

    @staticmethod
    async def enforce_binding(
        db: AsyncSession,
        school: School,
        teacher: Teacher,
        device_id: Optional[str],
    ) -> None:
        """Rejects an attendance scan from a device that is not the approved one."""
        if not school.device_binding_enabled:
            return

        if not device_id:
            raise AppException(
                code=ErrorCode.DEVICE_REQUIRED,
                message=(
                    "Тиркемени жаңыртыңыз: бул версия түзмөктү аныктабайт. "
                    "Каттоо үчүн жаңы версия талап кылынат."
                ),
                status_code=400,
            )

        device = (
            await db.execute(
                select(Device).where(
                    Device.user_id == teacher.user_id,
                    Device.device_id == device_id,
                )
            )
        ).scalar_one_or_none()

        if device is None or device.status != DeviceStatus.APPROVED:
            raise AppException(
                code=ErrorCode.DEVICE_NOT_APPROVED,
                message=(
                    "Бул түзмөк катталган эмес же ырасталган эмес. "
                    "Администраторго кайрылыңыз."
                ),
                status_code=403,
            )

    @staticmethod
    async def list_for_school(
        db: AsyncSession,
        school_id: str,
        teacher_id: Optional[str] = None,
        status: Optional[DeviceStatus] = None,
    ) -> List[Tuple[Device, User]]:
        query = (
            select(Device, User)
            .join(User, Device.user_id == User.id)
            .join(Teacher, Teacher.user_id == User.id)
            .options(selectinload(Device.user))
            .where(Teacher.school_id == school_id)
            .order_by(Device.created_at.desc())
        )
        if teacher_id:
            query = query.where(Teacher.id == teacher_id)
        if status:
            query = query.where(Device.status == status)
        return list((await db.execute(query)).all())

    @staticmethod
    async def _get_device_in_school(
        db: AsyncSession, device_id: str, school_id: str
    ) -> Device:
        row = (
            await db.execute(
                select(Device)
                .join(User, Device.user_id == User.id)
                .join(Teacher, Teacher.user_id == User.id)
                .where(Device.id == device_id, Teacher.school_id == school_id)
            )
        ).scalar_one_or_none()
        if row is None:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="Түзмөк табылган жок.",
                status_code=404,
            )
        return row

    @classmethod
    async def approve(
        cls, db: AsyncSession, device_id: str, school_id: str, admin_user: User
    ) -> Device:
        """Approves a device and revokes the teacher's previous one."""
        device = await cls._get_device_in_school(db, device_id, school_id)
        now = datetime.now(timezone.utc)

        replaced = []
        for other in await cls._approved_devices(db, device.user_id, exclude_id=device.id):
            cls._apply_status(other, DeviceStatus.REVOKED)
            other.revoked_at = now
            replaced.append(other.device_id)

        cls._apply_status(device, DeviceStatus.APPROVED)
        device.approved_at = now
        device.approved_by_id = admin_user.id
        device.revoked_at = None

        AuditService.add(
            db,
            school_id=school_id,
            user_id=admin_user.id,
            action="DEVICE_APPROVED",
            entity_name="device",
            entity_id=device.id,
            new_values={
                "device_id": device.device_id,
                "owner_user_id": device.user_id,
                "replaced_devices": replaced,
            },
        )
        await db.commit()
        await db.refresh(device)
        return device

    @classmethod
    async def revoke(
        cls, db: AsyncSession, device_id: str, school_id: str, admin_user: User
    ) -> Device:
        device = await cls._get_device_in_school(db, device_id, school_id)
        cls._apply_status(device, DeviceStatus.REVOKED)
        device.revoked_at = datetime.now(timezone.utc)

        AuditService.add(
            db,
            school_id=school_id,
            user_id=admin_user.id,
            action="DEVICE_REVOKED",
            entity_name="device",
            entity_id=device.id,
            new_values={
                "device_id": device.device_id,
                "owner_user_id": device.user_id,
            },
        )
        await db.commit()
        await db.refresh(device)
        return device
