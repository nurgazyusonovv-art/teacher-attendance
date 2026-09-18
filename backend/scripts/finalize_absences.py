"""Finalize ABSENT records for every active school.

Runs outside the request cycle (cron / scheduled job). Absence finalization
used to happen as a side effect of an admin GET request, which made a read
endpoint write to the database and put an unbounded day loop on the request
path. Schedule this instead, once per day after the latest school end time:

    python scripts/finalize_absences.py

The pass is idempotent: already finalized days are left untouched, and
EXCUSED records are never overwritten.
"""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select  # noqa: E402

from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.models.school import School  # noqa: E402
from app.services.absence_service import AbsenceService  # noqa: E402


async def finalize_all_schools() -> int:
    total = 0
    async with AsyncSessionLocal() as db:
        school_rows = await db.execute(
            select(School.id, School.name).where(School.is_active.is_(True))
        )
        schools = school_rows.all()

        for school_id, school_name in schools:
            try:
                created = await AbsenceService.catch_up(db, school_id)
            except Exception as exc:  # one bad school must not stop the rest
                await db.rollback()
                print(f"  ✗ {school_name}: {exc}", file=sys.stderr)
                continue
            total += created
            print(f"  ✓ {school_name}: {created} жазуу белгиленди")

    return total


async def main() -> None:
    print("⏳ Келбегендерди белгилөө башталды...")
    try:
        total = await finalize_all_schools()
    finally:
        await async_engine.dispose()
    print(f"✅ Бүттү. Жалпы {total} жазуу ABSENT катары белгиленди.")


if __name__ == "__main__":
    asyncio.run(main())
