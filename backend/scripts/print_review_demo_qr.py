"""Print what the App Store review notes need for the demo tenant.

The demo school's QR token is generated randomly and can be rotated, so it is
never hardcoded in the repository or in docs/APP_STORE_GUIDE.md. Run this
against the deployment being submitted and paste the result into the review
notes.

    python scripts/print_review_demo_qr.py
"""

import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select  # noqa: E402

from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.models.qr import QrCredential  # noqa: E402
from app.models.school import School  # noqa: E402


async def main() -> None:
    try:
        async with AsyncSessionLocal() as db:
            school = (
                await db.execute(
                    select(School).where(School.is_review_demo.is_(True))
                )
            ).scalars().first()

            if school is None:
                print(
                    "App Review demo мектеби табылган жок. "
                    "Адегенде scripts/seed.py жүргүзүңүз.",
                    file=sys.stderr,
                )
                raise SystemExit(1)

            # Read only. QrService.get_active_school_qr would mint a
            # credential when none exists, and a diagnostic run against
            # production must not write anything.
            credential = (
                await db.execute(
                    select(QrCredential).where(
                        QrCredential.school_id == school.id,
                        QrCredential.is_active.is_(True),
                    )
                )
            ).scalars().first()

            print("=== App Review demo tenant ===")
            print(f"  school      : {school.name} ({school.code})")
            print(f"  school_id   : {school.id}")
            print(f"  radius (m)  : {school.allowed_radius_meters:,.0f}")
            print(f"  max accuracy: {school.max_accuracy_meters:,.0f} m")

            if credential is None:
                print()
                print(
                    "  Активдүү QR жок. Админ панелинен demo мектептин QR-кодун "
                    "ачыңыз же scripts/seed.py жүргүзүңүз.",
                    file=sys.stderr,
                )
                raise SystemExit(2)

            print(f"  qr_token    : {credential.token}")
            print()
            print("QR payload for the reviewer:")
            print(
                json.dumps(
                    {
                        "type": "school_attendance",
                        "school_id": school.id,
                        "qr_token": credential.token,
                    },
                    indent=2,
                    ensure_ascii=False,
                )
            )
    finally:
        await async_engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
