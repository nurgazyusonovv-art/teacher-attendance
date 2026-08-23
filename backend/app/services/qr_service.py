import json
import secrets
from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppException, ErrorCode
from app.models.qr import QrCredential
from app.models.school import School
from app.schemas.qr import QrPayloadResponse


class QrService:
    @staticmethod
    async def get_active_school_qr(
        db: AsyncSession, school_id: str
    ) -> QrPayloadResponse:
        school_result = await db.execute(select(School).where(School.id == school_id))
        school = school_result.scalar_one_or_none()
        if not school:
            raise AppException(
                code=ErrorCode.NOT_FOUND,
                message="Мектеп табылган жок",
                status_code=404,
            )

        qr_result = await db.execute(
            select(QrCredential).where(
                QrCredential.school_id == school_id,
                QrCredential.is_active == True,  # noqa: E712
            )
        )
        qr_cred = qr_result.scalar_one_or_none()

        if not qr_cred:
            # Generate new static QR credential if none exists
            qr_token = f"school-qr-{secrets.token_urlsafe(24)}"
            qr_cred = QrCredential(
                school_id=school_id,
                token=qr_token,
                label="Негизги мектеп QR-коду",
                is_active=True,
            )
            db.add(qr_cred)
            await db.commit()
            await db.refresh(qr_cred)

        payload_dict = {
            "school_id": school.id,
            "qr_token": qr_cred.token,
        }
        return QrPayloadResponse(
            school_id=school.id,
            school_name=school.name,
            qr_token=qr_cred.token,
            qr_payload=json.dumps(payload_dict),
            created_at=qr_cred.created_at,
        )

    @staticmethod
    async def validate_qr_token(
        db: AsyncSession, school_id: str, qr_token: str
    ) -> QrCredential:
        result = await db.execute(
            select(QrCredential).where(
                QrCredential.school_id == school_id,
                QrCredential.token == qr_token,
                QrCredential.is_active == True,  # noqa: E712
            )
        )
        qr = result.scalar_one_or_none()
        if not qr:
            raise AppException(
                code=ErrorCode.QR_INVALID,
                message="QR-код жараксыз же эскирген",
                status_code=400,
            )
        return qr

    @staticmethod
    async def rotate_school_qr(
        db: AsyncSession, school_id: str, label: Optional[str] = None
    ) -> QrPayloadResponse:
        # Deactivate old credentials
        existing_result = await db.execute(
            select(QrCredential).where(
                QrCredential.school_id == school_id,
                QrCredential.is_active == True,  # noqa: E712
            )
        )
        for old_qr in existing_result.scalars().all():
            old_qr.is_active = False

        # Generate new credential
        new_token = f"school-qr-{secrets.token_urlsafe(24)}"
        new_qr = QrCredential(
            school_id=school_id,
            token=new_token,
            label=label or "Жаңыланган мектеп QR-коду",
            is_active=True,
        )
        db.add(new_qr)
        await db.commit()
        await db.refresh(new_qr)

        return await QrService.get_active_school_qr(db, school_id)
