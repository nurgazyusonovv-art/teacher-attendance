"""The App Review tenant (PROJECT.md §13).

A reviewer in Cupertino cannot stand inside a Bishkek geofence, and the demo
account no longer skips the geofence check. The reviewer path works because
the demo school carries its own worldwide radius — ordinary security code,
one unusual row — and that stays safe only while such a school holds demo
accounts alone.
"""

import uuid
from datetime import datetime, time
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.core.errors import ErrorCode
from app.core.security import get_password_hash
from app.models.enums import UserRole
from app.models.qr import QrCredential
from app.models.school import School
from app.models.schedule import WorkSchedule
from app.models.teacher import Teacher
from app.models.user import User

# Apple Park, far outside any Bishkek geofence.
CUPERTINO = (37.3349, -122.0090)

REVIEW_RADIUS_METERS = 20_100_000.0
REVIEW_MAX_ACCURACY_METERS = 100_000.0


async def _make_review_school(db_session, *, is_review_demo: bool = True) -> School:
    uid = uuid.uuid4().hex[:6]
    school = School(
        name="App Review Demo School",
        code=f"DEMO-{uid}",
        latitude=42.876500,
        longitude=74.603700,
        allowed_radius_meters=(
            REVIEW_RADIUS_METERS if is_review_demo else 80.0
        ),
        max_accuracy_meters=(
            REVIEW_MAX_ACCURACY_METERS if is_review_demo else 50.0
        ),
        default_start_time=time(8),
        default_end_time=time(17),
        grace_minutes=5,
        timezone="Asia/Bishkek",
        is_active=True,
        is_review_demo=is_review_demo,
    )
    db_session.add(school)
    await db_session.flush()

    db_session.add(QrCredential(school_id=school.id, label="Review QR"))
    for day in range(7):
        db_session.add(
            WorkSchedule(
                school_id=school.id,
                day_of_week=day,
                start_time=time(8),
                end_time=time(17),
                grace_minutes=5,
                is_day_off=False,
            )
        )
    await db_session.commit()
    return school


async def _add_teacher(
    db_session, school: School, *, is_demo: bool
) -> tuple[str, str]:
    uid = uuid.uuid4().hex[:6]
    username = f"{'demo' if is_demo else 'real'}_{uid}"
    password = "password123"
    user = User(
        username=username,
        email=f"{username}@example.com",
        full_name="Review Tester" if is_demo else "Real Teacher",
        hashed_password=get_password_hash(password),
        role=UserRole.TEACHER,
        is_demo=is_demo,
        school_id=school.id,
    )
    db_session.add(user)
    await db_session.flush()
    db_session.add(
        Teacher(
            user_id=user.id,
            school_id=school.id,
            employee_code=f"RV-{uid}",
            is_active=True,
        )
    )
    await db_session.commit()
    return username, password


async def _login(async_client: AsyncClient, username: str, password: str) -> dict:
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": username, "password": password},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['data']['access_token']}"}


async def _qr_token(db_session, school: School) -> str:
    row = await db_session.execute(
        select(QrCredential).where(
            QrCredential.school_id == school.id,
            QrCredential.is_active.is_(True),
        )
    )
    return row.scalars().first().token


@pytest.fixture(autouse=True)
def _monday_morning(monkeypatch):
    monkeypatch.setattr(
        "app.services.attendance_service.current_time_in_school_timezone",
        lambda _timezone: datetime(2026, 9, 7, 8, 0, tzinfo=ZoneInfo("Asia/Bishkek")),
    )


@pytest.mark.asyncio
async def test_reviewer_can_check_in_from_the_other_side_of_the_world(
    async_client: AsyncClient, db_session
):
    school = await _make_review_school(db_session)
    username, password = await _add_teacher(db_session, school, is_demo=True)
    headers = await _login(async_client, username, password)
    token = await _qr_token(db_session, school)

    payload = {
        "school_id": school.id,
        "qr_token": token,
        "latitude": CUPERTINO[0],
        "longitude": CUPERTINO[1],
        "accuracy": 65.0,
    }

    check_in = await async_client.post(
        "/api/v1/attendance/check-in", json=payload, headers=headers
    )
    assert check_in.status_code == 200, check_in.text
    assert check_in.json()["check_in_time"] is not None

    check_out = await async_client.post(
        "/api/v1/attendance/check-out", json=payload, headers=headers
    )
    assert check_out.status_code == 200
    assert check_out.json()["check_out_time"] is not None


@pytest.mark.asyncio
async def test_a_real_teacher_cannot_use_the_review_school(
    async_client: AsyncClient, db_session
):
    """The worldwide radius must never become a door for a real account."""
    school = await _make_review_school(db_session)
    username, password = await _add_teacher(db_session, school, is_demo=False)
    headers = await _login(async_client, username, password)
    token = await _qr_token(db_session, school)

    response = await async_client.post(
        "/api/v1/attendance/check-in",
        json={
            "school_id": school.id,
            "qr_token": token,
            "latitude": CUPERTINO[0],
            "longitude": CUPERTINO[1],
            "accuracy": 65.0,
        },
        headers=headers,
    )
    assert response.status_code == 403
    assert response.json()["code"] == ErrorCode.REVIEW_SCHOOL_FORBIDDEN.value


@pytest.mark.asyncio
async def test_check_out_is_guarded_the_same_way(
    async_client: AsyncClient, db_session
):
    school = await _make_review_school(db_session)
    username, password = await _add_teacher(db_session, school, is_demo=False)
    headers = await _login(async_client, username, password)
    token = await _qr_token(db_session, school)

    response = await async_client.post(
        "/api/v1/attendance/check-out",
        json={
            "school_id": school.id,
            "qr_token": token,
            "latitude": CUPERTINO[0],
            "longitude": CUPERTINO[1],
            "accuracy": 65.0,
        },
        headers=headers,
    )
    assert response.status_code == 403
    assert response.json()["code"] == ErrorCode.REVIEW_SCHOOL_FORBIDDEN.value


@pytest.mark.asyncio
async def test_the_demo_flag_alone_grants_nothing_in_an_ordinary_school(
    async_client: AsyncClient, db_session
):
    """Being a demo account is not what opens the geofence — the school is."""
    school = await _make_review_school(db_session, is_review_demo=False)
    username, password = await _add_teacher(db_session, school, is_demo=True)
    headers = await _login(async_client, username, password)
    token = await _qr_token(db_session, school)

    response = await async_client.post(
        "/api/v1/attendance/check-in",
        json={
            "school_id": school.id,
            "qr_token": token,
            "latitude": CUPERTINO[0],
            "longitude": CUPERTINO[1],
            "accuracy": 20.0,
        },
        headers=headers,
    )
    assert response.status_code == 400
    assert response.json()["code"] == ErrorCode.LOCATION_OUTSIDE_SCHOOL.value


@pytest.mark.asyncio
async def test_the_flag_cannot_be_set_through_the_api(
    async_client: AsyncClient, admin_auth_headers: dict, db_session
):
    """SchoolUpdate has no is_review_demo field, so a PATCH cannot open a school."""
    school = (
        await db_session.execute(
            select(School).where(School.is_review_demo.is_(False)).limit(1)
        )
    ).scalars().first()
    assert school is not None

    response = await async_client.patch(
        f"/api/v1/schools/{school.id}",
        json={"is_review_demo": True},
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    assert response.json()["is_review_demo"] is False

    await db_session.refresh(school)
    assert school.is_review_demo is False
