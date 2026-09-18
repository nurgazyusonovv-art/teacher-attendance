"""Provisioning for the isolated App Review tenant (PROJECT.md §13).

An App Store reviewer is not in Bishkek, and no account flag opens the
geofence any more. The reviewer works because this one school carries its own
worldwide radius, which is safe only while the school holds demo accounts
alone — AttendanceService enforces that.

Everything here touches the review school and its demo teacher only. It never
reads or writes a production school, which is what makes it safe to run
against a live deployment, unlike the full bootstrap seed.
"""

from dataclasses import dataclass
from datetime import time
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.models.enums import UserRole
from app.models.qr import QrCredential
from app.models.school import School
from app.models.schedule import WorkSchedule
from app.models.teacher import Teacher
from app.models.user import User

REVIEW_SCHOOL_CODE = "DEMO-001"
REVIEW_SCHOOL_NAME = "App Review Demo School"
REVIEW_USERNAME = "demo_teacher"
REVIEW_EMAIL = "demo@school.edu.kg"
REVIEW_EMPLOYEE_CODE = "DEMO-TCH-001"

# Half of Earth's circumference is ~20 040 km, so every point is inside.
REVIEW_RADIUS_METERS = 20_100_000.0
# A simulator or desktop browser reports a very coarse position.
REVIEW_MAX_ACCURACY_METERS = 100_000.0


@dataclass
class ReviewTenant:
    school: School
    credential: QrCredential
    user: User
    created: bool

    @property
    def qr_payload(self) -> dict:
        return {
            "type": "school_attendance",
            "school_id": self.school.id,
            "qr_token": self.credential.token,
        }


async def provision(
    db: AsyncSession, password: Optional[str] = None
) -> ReviewTenant:
    """Creates or repairs the review tenant. Idempotent.

    `password` is applied only when the demo user is first created, so a
    re-run never silently rotates a credential already sitting in the App
    Store Connect review notes.
    """
    created = False

    school = (
        await db.execute(select(School).where(School.code == REVIEW_SCHOOL_CODE))
    ).scalar_one_or_none()
    if school is None:
        if not password:
            raise ValueError(
                "A password is required to create the review tenant."
            )
        school = School(
            name=REVIEW_SCHOOL_NAME,
            code=REVIEW_SCHOOL_CODE,
            latitude=42.876500,
            longitude=74.603700,
            allowed_radius_meters=REVIEW_RADIUS_METERS,
            max_accuracy_meters=REVIEW_MAX_ACCURACY_METERS,
            default_start_time=time(8, 0),
            default_end_time=time(17, 0),
            grace_minutes=5,
            timezone="Asia/Bishkek",
            is_active=True,
            is_review_demo=True,
        )
        db.add(school)
        await db.flush()
        created = True
    else:
        # Repair a row that predates the flag, or that someone narrowed.
        school.is_review_demo = True
        school.allowed_radius_meters = REVIEW_RADIUS_METERS
        school.max_accuracy_meters = REVIEW_MAX_ACCURACY_METERS
        school.is_active = True

    # Reviewers test on whatever weekday they happen to pick.
    existing_days = {
        row.day_of_week
        for row in (
            await db.execute(
                select(WorkSchedule).where(
                    WorkSchedule.school_id == school.id,
                    WorkSchedule.teacher_id.is_(None),
                )
            )
        ).scalars()
    }
    for day in range(7):
        if day in existing_days:
            continue
        db.add(
            WorkSchedule(
                school_id=school.id,
                teacher_id=None,
                day_of_week=day,
                start_time=time(8, 0),
                end_time=time(17, 0),
                grace_minutes=5,
                is_day_off=False,
            )
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
        credential = QrCredential(
            school_id=school.id,
            label="App Review demo QR",
            is_active=True,
        )
        db.add(credential)
        await db.flush()

    user = (
        await db.execute(select(User).where(User.username == REVIEW_USERNAME))
    ).scalar_one_or_none()
    if user is None:
        if not password:
            raise ValueError(
                "A password is required to create the review account."
            )
        user = User(
            username=REVIEW_USERNAME,
            email=REVIEW_EMAIL,
            hashed_password=get_password_hash(password),
            full_name="App Review Demo Teacher",
            role=UserRole.TEACHER,
            is_active=True,
            is_demo=True,
            school_id=school.id,
        )
        db.add(user)
        await db.flush()
        created = True
    else:
        # A demo account must never end up pointing at a production school.
        user.is_demo = True
        user.is_active = True
        user.school_id = school.id

    teacher = (
        await db.execute(select(Teacher).where(Teacher.user_id == user.id))
    ).scalar_one_or_none()
    if teacher is None:
        teacher = Teacher(
            user_id=user.id,
            school_id=school.id,
            employee_code=REVIEW_EMPLOYEE_CODE,
            is_active=True,
        )
        db.add(teacher)
    else:
        teacher.school_id = school.id
        teacher.is_active = True

    await db.commit()
    await db.refresh(school)
    await db.refresh(credential)
    await db.refresh(user)
    return ReviewTenant(
        school=school, credential=credential, user=user, created=created
    )
