"""Verify duplicate check-in serialization against an isolated local PostgreSQL DB."""

import asyncio
import sys
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select  # noqa: E402
from sqlalchemy.orm import selectinload  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.errors import AppException  # noqa: E402
from app.core.timezone import today_date_in_school_timezone  # noqa: E402
from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.models.attendance import AttendanceEvent  # noqa: E402
from app.models.daily_attendance import DailyAttendance  # noqa: E402
from app.models.qr import QrCredential  # noqa: E402
from app.models.teacher import Teacher  # noqa: E402
from app.models.user import User  # noqa: E402
from app.schemas.attendance import AttendanceScanRequest  # noqa: E402
from app.services.attendance_service import AttendanceService  # noqa: E402


def _assert_isolated_local_database() -> None:
    parsed = urlparse(settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql"))
    if settings.ENVIRONMENT.lower() != "test":
        raise RuntimeError("Concurrency check only runs with ENVIRONMENT=test")
    if parsed.hostname not in {"localhost", "127.0.0.1", "::1"}:
        raise RuntimeError("Concurrency check only runs against local PostgreSQL")


async def _attempt_check_in(teacher_id: str, payload: AttendanceScanRequest) -> str:
    async with AsyncSessionLocal() as db:
        teacher = (
            await db.execute(
                select(Teacher)
                .options(selectinload(Teacher.user))
                .where(Teacher.id == teacher_id)
            )
        ).scalar_one()
        try:
            await AttendanceService.register_check_in(
                db=db,
                teacher=teacher,
                user=teacher.user,
                payload=payload,
            )
            return "CREATED"
        except AppException as error:
            return error.code.value


async def main() -> None:
    _assert_isolated_local_database()
    async with AsyncSessionLocal() as db:
        teacher = (
            await db.execute(
                select(Teacher)
                .join(User, User.id == Teacher.user_id)
                .options(selectinload(Teacher.school))
                .where(User.username == "demo_teacher")
            )
        ).scalar_one()
        qr = (
            await db.execute(
                select(QrCredential).where(
                    QrCredential.school_id == teacher.school_id,
                    QrCredential.is_active.is_(True),
                )
            )
        ).scalar_one()
        target_date = today_date_in_school_timezone(teacher.school.timezone)
        await db.execute(
            delete(AttendanceEvent).where(AttendanceEvent.teacher_id == teacher.id)
        )
        await db.execute(
            delete(DailyAttendance).where(
                DailyAttendance.teacher_id == teacher.id,
                DailyAttendance.date == target_date,
            )
        )
        await db.commit()
        payload = AttendanceScanRequest(
            school_id=teacher.school_id,
            qr_token=qr.token,
            latitude=teacher.school.latitude,
            longitude=teacher.school.longitude,
            accuracy=5,
            device_info="postgres-concurrency-check",
        )
        teacher_id = teacher.id

    outcomes = await asyncio.gather(
        _attempt_check_in(teacher_id, payload),
        _attempt_check_in(teacher_id, payload),
    )
    if sorted(outcomes) != ["ALREADY_CHECKED_IN", "CREATED"]:
        raise AssertionError(f"Unexpected concurrent outcomes: {outcomes}")
    print("PostgreSQL concurrent check-in protection: passed")
    await async_engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
