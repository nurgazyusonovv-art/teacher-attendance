"""Provisioning the App Review tenant on a live deployment.

The full bootstrap seed cannot be used for this: it also creates a fake
administrator and a fake teacher inside the real school. These tests pin the
property that matters — provisioning touches the review tenant and nothing
else — plus idempotency, since it will be re-run.
"""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import func, select

from app.models.enums import UserRole
from app.models.qr import QrCredential
from app.models.school import School
from app.models.schedule import WorkSchedule
from app.models.teacher import Teacher
from app.models.user import User
from app.services import review_tenant_service as rts


@pytest.fixture(autouse=True)
async def _clean_tenant(db_session):
    """The test database is shared, so start each test without the tenant."""

    async def remove() -> None:
        school = (
            await db_session.execute(
                select(School).where(School.code == rts.REVIEW_SCHOOL_CODE)
            )
        ).scalar_one_or_none()
        user = (
            await db_session.execute(
                select(User).where(User.username == rts.REVIEW_USERNAME)
            )
        ).scalar_one_or_none()
        if user is not None:
            await db_session.delete(user)
        if school is not None:
            await db_session.delete(school)
        await db_session.commit()

    await remove()
    yield
    await remove()


async def _snapshot_production(db_session) -> dict:
    """Everything outside the review tenant, to prove it stays untouched."""
    schools = (
        await db_session.execute(
            select(School).where(School.code != rts.REVIEW_SCHOOL_CODE)
        )
    ).scalars().all()
    user_count = (
        await db_session.execute(
            select(func.count()).select_from(User).where(
                User.username != rts.REVIEW_USERNAME
            )
        )
    ).scalar_one()
    return {
        "schools": {
            s.code: (s.name, s.allowed_radius_meters, s.is_review_demo)
            for s in schools
        },
        "users": user_count,
    }


@pytest.mark.asyncio
async def test_provisioning_creates_a_usable_isolated_tenant(db_session):
    before = await _snapshot_production(db_session)

    tenant = await rts.provision(db_session, "review-password-123")

    assert tenant.created is True
    assert tenant.school.code == rts.REVIEW_SCHOOL_CODE
    assert tenant.school.is_review_demo is True
    assert tenant.school.allowed_radius_meters == rts.REVIEW_RADIUS_METERS
    assert tenant.user.is_demo is True
    assert tenant.user.role == UserRole.TEACHER
    assert tenant.user.school_id == tenant.school.id

    # A reviewer may test on any weekday.
    days = (
        await db_session.execute(
            select(WorkSchedule.day_of_week).where(
                WorkSchedule.school_id == tenant.school.id,
                WorkSchedule.teacher_id.is_(None),
            )
        )
    ).scalars().all()
    assert sorted(days) == list(range(7))

    teacher = (
        await db_session.execute(
            select(Teacher).where(Teacher.user_id == tenant.user.id)
        )
    ).scalar_one()
    assert teacher.school_id == tenant.school.id

    assert tenant.qr_payload["type"] == "school_attendance"
    assert tenant.qr_payload["school_id"] == tenant.school.id
    assert tenant.qr_payload["qr_token"] == tenant.credential.token

    # The real school is exactly as it was.
    assert await _snapshot_production(db_session) == before


@pytest.mark.asyncio
async def test_provisioning_is_idempotent_and_keeps_the_password(db_session):
    first = await rts.provision(db_session, "review-password-123")
    original_hash = first.user.hashed_password
    original_token = first.credential.token

    second = await rts.provision(db_session)

    assert second.created is False
    assert second.school.id == first.school.id
    assert second.user.hashed_password == original_hash
    assert second.credential.token == original_token

    schools = (
        await db_session.execute(
            select(func.count()).select_from(School).where(
                School.code == rts.REVIEW_SCHOOL_CODE
            )
        )
    ).scalar_one()
    assert schools == 1

    credentials = (
        await db_session.execute(
            select(func.count()).select_from(QrCredential).where(
                QrCredential.school_id == first.school.id,
                QrCredential.is_active.is_(True),
            )
        )
    ).scalar_one()
    assert credentials == 1


@pytest.mark.asyncio
async def test_provisioning_repairs_a_narrowed_or_unflagged_tenant(db_session):
    tenant = await rts.provision(db_session, "review-password-123")

    # Someone narrowed the radius or the row predates the flag.
    tenant.school.is_review_demo = False
    tenant.school.allowed_radius_meters = 80.0
    tenant.school.is_active = False
    await db_session.commit()

    repaired = await rts.provision(db_session)
    assert repaired.school.is_review_demo is True
    assert repaired.school.allowed_radius_meters == rts.REVIEW_RADIUS_METERS
    assert repaired.school.is_active is True


@pytest.mark.asyncio
async def test_creating_without_a_password_is_refused(db_session):
    with pytest.raises(ValueError):
        await rts.provision(db_session)


@pytest.mark.asyncio
async def test_password_rotation_is_opt_in_and_revokes_sessions(db_session):
    from app.core.security import verify_password
    from app.models.auth_security import AuthSession

    tenant = await rts.provision(db_session, "review-password-123")
    original_hash = tenant.user.hashed_password

    # A session held by whoever knew the old password.
    db_session.add(
        AuthSession(
            user_id=tenant.user.id,
            refresh_jti_hash="rotation-test-hash",
            expires_at=datetime.now(timezone.utc) + timedelta(days=1),
        )
    )
    await db_session.commit()

    # Without the flag the password is left alone, even if one is supplied.
    untouched = await rts.provision(db_session, "a-different-password")
    assert untouched.password_rotated is False
    assert untouched.user.hashed_password == original_hash

    rotated = await rts.provision(
        db_session, "brand-new-password-456", rotate_password=True
    )
    assert rotated.password_rotated is True
    assert verify_password("brand-new-password-456", rotated.user.hashed_password)
    assert not verify_password("review-password-123", rotated.user.hashed_password)

    live = (
        await db_session.execute(
            select(func.count()).select_from(AuthSession).where(
                AuthSession.user_id == tenant.user.id,
                AuthSession.revoked_at.is_(None),
            )
        )
    ).scalar_one()
    assert live == 0


@pytest.mark.asyncio
async def test_rotation_without_a_password_is_refused(db_session):
    await rts.provision(db_session, "review-password-123")
    with pytest.raises(ValueError):
        await rts.provision(db_session, rotate_password=True)
