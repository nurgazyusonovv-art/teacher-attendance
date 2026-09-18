"""Walk the App Review path against a live deployment, as a reviewer would.

Signs in as the demo teacher, scans the demo QR from Cupertino coordinates and
records a check-in and a check-out — the exact sequence an App Store reviewer
performs. Run it before submitting a build.

    REVIEW_DEMO_PASSWORD='...' python scripts/verify_review_flow.py

The QR token and school id are read from the database; the password stays in
the environment and is never printed. Attendance rows are written to the demo
tenant only, which is what that tenant exists for.
"""

import asyncio
import os
import sys

import httpx
from sqlalchemy import select

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.session import AsyncSessionLocal, async_engine  # noqa: E402
from app.models.qr import QrCredential  # noqa: E402
from app.models.school import School  # noqa: E402
from app.services import review_tenant_service as rts  # noqa: E402

# Apple Park — far outside any Kyrgyz geofence.
CUPERTINO_LAT = 37.3349
CUPERTINO_LON = -122.0090
REPORTED_ACCURACY_METERS = 65.0

DEFAULT_API = "https://teacher-attendance-api-hfh2.onrender.com/api/v1"


def _ok(label: str, detail: str = "") -> None:
    print(f"  ✓ {label}" + (f" — {detail}" if detail else ""))


def _fail(label: str, detail: str) -> None:
    print(f"  ✗ {label} — {detail}")


async def _tenant() -> tuple[str, str]:
    async with AsyncSessionLocal() as db:
        school = (
            await db.execute(
                select(School).where(School.is_review_demo.is_(True))
            )
        ).scalars().first()
        if school is None:
            raise SystemExit(
                "Review tenant табылган жок. "
                "scripts/provision_review_tenant.py жүргүзүңүз."
            )
        credential = (
            await db.execute(
                select(QrCredential).where(
                    QrCredential.school_id == school.id,
                    QrCredential.is_active.is_(True),
                )
            )
        ).scalars().first()
        if credential is None:
            raise SystemExit("Demo мектепте активдүү QR жок.")
        return school.id, credential.token


async def main() -> None:
    password = os.getenv("REVIEW_DEMO_PASSWORD")
    if not password:
        print("REVIEW_DEMO_PASSWORD коюңуз.", file=sys.stderr)
        raise SystemExit(1)
    api = os.getenv("REVIEW_API_BASE", DEFAULT_API).rstrip("/")

    try:
        school_id, qr_token = await _tenant()
    finally:
        await async_engine.dispose()

    failures = 0
    print(f"API: {api}")
    print(f"Локация: Cupertino ({CUPERTINO_LAT}, {CUPERTINO_LON})\n")

    async with httpx.AsyncClient(timeout=90.0) as client:
        login = await client.post(
            f"{api}/auth/login",
            json={
                "username_or_email": rts.REVIEW_USERNAME,
                "password": password,
            },
        )
        if login.status_code != 200:
            _fail("login", login.json().get("message", login.text))
            raise SystemExit(1)
        data = login.json()["data"]
        user = data["user"]
        headers = {"Authorization": f"Bearer {data['access_token']}"}
        _ok(
            "login",
            f"{user['username']}, is_demo={user['is_demo']}, role={user['role']}",
        )

        today = await client.get(f"{api}/attendance/today", headers=headers)
        if today.status_code == 200:
            body = today.json()
            _ok(
                "бүгүнкү статус",
                f"{body['school_name']}, {body['date']}, {body['display_status']}",
            )
        else:
            failures += 1
            _fail("бүгүнкү статус", today.text[:160])

        scan = {
            "school_id": school_id,
            "qr_token": qr_token,
            "latitude": CUPERTINO_LAT,
            "longitude": CUPERTINO_LON,
            "accuracy": REPORTED_ACCURACY_METERS,
        }

        check_in = await client.post(
            f"{api}/attendance/check-in", json=scan, headers=headers
        )
        if check_in.status_code == 200:
            _ok("check-in", f"убакыт {check_in.json()['check_in_time']}")
        elif check_in.json().get("code") == "ALREADY_CHECKED_IN":
            _ok("check-in", "бүгүн мурда катталган (кайра иштетүү)")
        else:
            failures += 1
            _fail("check-in", check_in.text[:200])

        check_out = await client.post(
            f"{api}/attendance/check-out", json=scan, headers=headers
        )
        if check_out.status_code == 200:
            body = check_out.json()
            _ok(
                "check-out",
                f"убакыт {body['check_out_time']}, "
                f"иштеген {body['worked_minutes']} мүн",
            )
        elif check_out.json().get("code") == "ALREADY_CHECKED_OUT":
            _ok("check-out", "бүгүн мурда катталган (кайра иштетүү)")
        else:
            failures += 1
            _fail("check-out", check_out.text[:200])

        history = await client.get(f"{api}/attendance/my-history", headers=headers)
        if history.status_code == 200:
            _ok("тарых", f"{len(history.json())} жазуу")
        else:
            failures += 1
            _fail("тарых", history.text[:160])

        # The reviewer's QR must not work against any other school.
        wrong = await client.post(
            f"{api}/attendance/check-in",
            json={**scan, "qr_token": "school-qr-not-a-real-token-000000"},
            headers=headers,
        )
        if wrong.status_code == 400 and wrong.json().get("code") == "QR_INVALID":
            _ok("жараксыз QR четке кагылды")
        else:
            failures += 1
            _fail("жараксыз QR", f"{wrong.status_code} {wrong.text[:120]}")

    print()
    if failures:
        print(f"❌ {failures} текшерүү кулады.")
        raise SystemExit(1)
    print("✅ App Review агымы толук иштейт.")


if __name__ == "__main__":
    asyncio.run(main())
