import json
from typing import Any, Mapping, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit import AuditLog


class AuditService:
    _SENSITIVE_KEYS = {"password", "hashed_password", "token", "qr_token", "telegram_bot_token"}

    @classmethod
    def _sanitize(cls, values: Optional[Mapping[str, Any]]) -> Optional[str]:
        if values is None:
            return None
        sanitized = {
            key: "[REDACTED]" if key.lower() in cls._SENSITIVE_KEYS else value
            for key, value in values.items()
        }
        return json.dumps(sanitized, default=str, ensure_ascii=False)

    @classmethod
    def add(
        cls,
        db: AsyncSession,
        *,
        school_id: Optional[str],
        user_id: Optional[str],
        action: str,
        entity_name: str,
        entity_id: Optional[str],
        old_values: Optional[Mapping[str, Any]] = None,
        new_values: Optional[Mapping[str, Any]] = None,
        ip_address: Optional[str] = None,
    ) -> AuditLog:
        entry = AuditLog(
            school_id=school_id,
            user_id=user_id,
            action=action,
            entity_name=entity_name,
            entity_id=entity_id,
            old_values=cls._sanitize(old_values),
            new_values=cls._sanitize(new_values),
            ip_address=ip_address,
        )
        db.add(entry)
        return entry
