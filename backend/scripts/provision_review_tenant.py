"""Create the App Review demo tenant on a live deployment.

Unlike scripts/seed.py this touches nothing but the review school and its demo
teacher — seed would also inject a fake administrator and a fake teacher into
the real school, where they would show up in the dashboard, the reports and
the absence counts.

    ALLOW_REVIEW_TENANT_PROVISION=true \\
    REVIEW_DEMO_PASSWORD='...' \\
    python scripts/provision_review_tenant.py

Idempotent: re-running repairs the tenant and never rotates an existing
password, so the credentials already in the App Store Connect review notes
keep working.

To deliberately set a new password — the only way to change it, since an
administrator is scoped to their own school and cannot reach this account —
add REVIEW_DEMO_ROTATE_PASSWORD=true. Every existing session is revoked.
"""

import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.services import review_tenant_service  # noqa: E402


async def main() -> None:
    if os.getenv("ALLOW_REVIEW_TENANT_PROVISION", "").lower() != "true":
        print(
            "Бул скрипт базага жазат. Атайын уруксат бериңиз: "
            "ALLOW_REVIEW_TENANT_PROVISION=true",
            file=sys.stderr,
        )
        raise SystemExit(1)

    password = os.getenv("REVIEW_DEMO_PASSWORD")
    rotate = os.getenv("REVIEW_DEMO_ROTATE_PASSWORD", "").lower() == "true"

    try:
        async with AsyncSessionLocal() as db:
            try:
                tenant = await review_tenant_service.provision(
                    db, password, rotate_password=rotate
                )
            except ValueError as exc:
                print(f"{exc} REVIEW_DEMO_PASSWORD коюңуз.", file=sys.stderr)
                raise SystemExit(1) from exc

            print(
                "✓ Review tenant "
                + ("түзүлдү" if tenant.created else "мурдатан бар, жаңыртылды")
            )
            print()
            print("=== App Review demo tenant ===")
            print(f"  school      : {tenant.school.name} ({tenant.school.code})")
            print(f"  school_id   : {tenant.school.id}")
            print(f"  username    : {tenant.user.username}")
            print(f"  qr_token    : {tenant.credential.token}")
            print(f"  radius (m)  : {tenant.school.allowed_radius_meters:,.0f}")
            print()
            print("QR payload for the review notes:")
            print(json.dumps(tenant.qr_payload, indent=2, ensure_ascii=False))
            if tenant.password_rotated:
                print()
                print("  Сырсөз жаңыртылды, эски сессиялар жокко чыгарылды.")
            elif not tenant.created:
                print()
                print(
                    "  Сырсөз өзгөртүлгөн жок. Жаңыртуу үчүн "
                    "REVIEW_DEMO_ROTATE_PASSWORD=true кошуңуз."
                )
    finally:
        await async_engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
