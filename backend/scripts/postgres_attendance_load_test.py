"""Run a disposable attendance load test against an isolated local PostgreSQL DB."""

import argparse
import asyncio
import math
import secrets
import statistics
import sys
import time as monotonic_time
import uuid
from dataclasses import dataclass
from datetime import time
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, func, select  # noqa: E402
from sqlalchemy.orm import selectinload  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.core.timezone import today_date_in_school_timezone  # noqa: E402
from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.models.attendance import AttendanceEvent  # noqa: E402
from app.models.daily_attendance import DailyAttendance  # noqa: E402
from app.models.enums import UserRole  # noqa: E402
from app.models.qr import QrCredential  # noqa: E402
from app.models.schedule import WorkSchedule  # noqa: E402
from app.models.school import School  # noqa: E402
from app.models.teacher import Teacher  # noqa: E402
from app.models.user import User  # noqa: E402
from app.schemas.attendance import AttendanceScanRequest  # noqa: E402
from app.services.attendance_service import AttendanceService  # noqa: E402


@dataclass(frozen=True)
class LoadTestFixture:
    school_id: str
    teacher_ids: list[str]
    payload: AttendanceScanRequest


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Exercise concurrent attendance check-ins on local PostgreSQL."
    )
    parser.add_argument("--teachers", type=int, default=500)
    parser.add_argument("--concurrency", type=int, default=50)
    args = parser.parse_args()
    if not 1 <= args.teachers <= 10_000:
        parser.error("--teachers must be between 1 and 10000")
    if not 1 <= args.concurrency <= args.teachers:
        parser.error("--concurrency must be between 1 and --teachers")
    return args


def _assert_isolated_local_database() -> None:
    parsed = urlparse(
        settings.DATABASE_URL.replace("postgresql+asyncpg", "postgresql")
    )
    if settings.ENVIRONMENT.lower() != "test":
        raise RuntimeError("Load test only runs with ENVIRONMENT=test")
    if parsed.scheme != "postgresql":
        raise RuntimeError("Load test requires PostgreSQL")
    if parsed.hostname not in {"localhost", "127.0.0.1", "::1"}:
        raise RuntimeError("Load test only runs against local PostgreSQL")


async def _create_fixture(teacher_count: int) -> LoadTestFixture:
    run_id = uuid.uuid4().hex[:12]
    school_id = str(uuid.uuid4())
    qr_token = secrets.token_urlsafe(32)
    target_date = today_date_in_school_timezone("Asia/Bishkek")
    teacher_ids: list[str] = []

    async with AsyncSessionLocal() as db:
        db.add(
            School(
                id=school_id,
                name=f"Attendance load test {run_id}",
                code=f"load-{run_id}",
                latitude=42.8746,
                longitude=74.5698,
                allowed_radius_meters=80,
                max_accuracy_meters=50,
                default_start_time=time(8, 0),
                default_end_time=time(17, 0),
                timezone="Asia/Bishkek",
            )
        )
        db.add(
            WorkSchedule(
                school_id=school_id,
                day_of_week=target_date.weekday(),
                start_time=time(0, 0),
                end_time=time(23, 59),
                grace_minutes=24 * 60,
                is_day_off=False,
            )
        )
        db.add(
            QrCredential(
                school_id=school_id,
                token=qr_token,
                label="Disposable load-test QR",
                is_active=True,
            )
        )

        for index in range(teacher_count):
            user_id = str(uuid.uuid4())
            teacher_id = str(uuid.uuid4())
            teacher_ids.append(teacher_id)
            db.add(
                User(
                    id=user_id,
                    email=f"load-{run_id}-{index}@invalid.local",
                    username=f"load-{run_id}-{index}",
                    hashed_password="not-used-by-load-test",
                    full_name=f"Load Test Teacher {index}",
                    role=UserRole.TEACHER,
                    is_active=True,
                    is_demo=False,
                    school_id=school_id,
                )
            )
            db.add(
                Teacher(
                    id=teacher_id,
                    user_id=user_id,
                    school_id=school_id,
                    employee_code=f"load-{run_id}-{index}",
                    is_active=True,
                )
            )
        await db.commit()

    return LoadTestFixture(
        school_id=school_id,
        teacher_ids=teacher_ids,
        payload=AttendanceScanRequest(
            school_id=school_id,
            qr_token=qr_token,
            latitude=42.8746,
            longitude=74.5698,
            accuracy=5,
            device_info="postgres-attendance-load-test",
        ),
    )


async def _check_in(
    teacher_id: str,
    payload: AttendanceScanRequest,
    semaphore: asyncio.Semaphore,
) -> float:
    async with semaphore, AsyncSessionLocal() as db:
        teacher = (
            await db.execute(
                select(Teacher)
                .options(selectinload(Teacher.user))
                .where(Teacher.id == teacher_id)
            )
        ).scalar_one()
        started = monotonic_time.perf_counter()
        await AttendanceService.register_check_in(
            db=db,
            teacher=teacher,
            user=teacher.user,
            payload=payload,
        )
        return monotonic_time.perf_counter() - started


async def _verify_results(fixture: LoadTestFixture) -> None:
    async with AsyncSessionLocal() as db:
        daily_count = await db.scalar(
            select(func.count(DailyAttendance.id)).where(
                DailyAttendance.school_id == fixture.school_id
            )
        )
        event_count = await db.scalar(
            select(func.count(AttendanceEvent.id)).where(
                AttendanceEvent.school_id == fixture.school_id
            )
        )
    expected = len(fixture.teacher_ids)
    if daily_count != expected or event_count != expected:
        raise AssertionError(
            "Attendance count mismatch: "
            f"expected={expected}, daily={daily_count}, events={event_count}"
        )


async def _cleanup(fixture: LoadTestFixture) -> None:
    async with AsyncSessionLocal() as db:
        await db.execute(
            delete(AttendanceEvent).where(
                AttendanceEvent.school_id == fixture.school_id
            )
        )
        await db.execute(
            delete(DailyAttendance).where(
                DailyAttendance.school_id == fixture.school_id
            )
        )
        await db.execute(
            delete(WorkSchedule).where(WorkSchedule.school_id == fixture.school_id)
        )
        await db.execute(
            delete(QrCredential).where(QrCredential.school_id == fixture.school_id)
        )
        await db.execute(delete(Teacher).where(Teacher.school_id == fixture.school_id))
        await db.execute(delete(User).where(User.school_id == fixture.school_id))
        await db.execute(delete(School).where(School.id == fixture.school_id))
        await db.commit()


def _percentile(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    index = max(0, math.ceil(len(ordered) * percentile) - 1)
    return ordered[index]


async def main() -> None:
    args = _parse_args()
    _assert_isolated_local_database()
    fixture: LoadTestFixture | None = None
    try:
        fixture = await _create_fixture(args.teachers)
        semaphore = asyncio.Semaphore(args.concurrency)
        started = monotonic_time.perf_counter()
        latencies = await asyncio.gather(
            *(
                _check_in(teacher_id, fixture.payload, semaphore)
                for teacher_id in fixture.teacher_ids
            )
        )
        elapsed = monotonic_time.perf_counter() - started
        await _verify_results(fixture)

        print("PostgreSQL attendance load test: passed")
        print(f"teachers={args.teachers} concurrency={args.concurrency}")
        print(f"elapsed_seconds={elapsed:.3f}")
        print(f"throughput_requests_per_second={args.teachers / elapsed:.1f}")
        print(f"latency_p50_ms={statistics.median(latencies) * 1000:.1f}")
        print(f"latency_p95_ms={_percentile(latencies, 0.95) * 1000:.1f}")
        print(f"latency_max_ms={max(latencies) * 1000:.1f}")
    finally:
        if fixture is not None:
            await _cleanup(fixture)
        await async_engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
