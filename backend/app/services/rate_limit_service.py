from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import AppException, ErrorCode
from app.models.auth_security import AttendanceRateBucket


class RateLimitService:
    @staticmethod
    async def enforce_attendance_limit(
        db: AsyncSession, user_id: str, *, retry_on_conflict: bool = True
    ) -> None:
        now = datetime.now(timezone.utc)
        result = await db.execute(
            select(AttendanceRateBucket)
            .where(AttendanceRateBucket.user_id == user_id)
            .with_for_update()
        )
        bucket = result.scalar_one_or_none()
        if bucket is None:
            bucket = AttendanceRateBucket(
                user_id=user_id, window_started_at=now, request_count=1
            )
            db.add(bucket)
        else:
            started_at = bucket.window_started_at
            if started_at.tzinfo is None:
                started_at = started_at.replace(tzinfo=timezone.utc)
            if now - started_at >= timedelta(minutes=1):
                bucket.window_started_at = now
                bucket.request_count = 1
            else:
                bucket.request_count += 1
                if bucket.request_count > settings.ATTENDANCE_RATE_LIMIT_PER_MINUTE:
                    await db.commit()
                    raise AppException(
                        code=ErrorCode.RATE_LIMITED,
                        message="Өтө көп attendance аракети. Бир мүнөттөн кийин кайталаңыз.",
                        status_code=429,
                    )
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            if not retry_on_conflict:
                raise
            # A concurrent first request created the bucket. Retry exactly once
            # against the now-existing locked row.
            await RateLimitService.enforce_attendance_limit(
                db, user_id, retry_on_conflict=False
            )
