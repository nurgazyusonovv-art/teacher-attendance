import asyncio
import os
import sys
from datetime import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.core.security import get_password_hash
from app.models.enums import UserRole
from app.models.school import School
from app.models.user import User
from app.models.teacher import Teacher
from app.models.schedule import WorkSchedule
from app.models.qr import QrCredential
from app.services import review_tenant_service


async def seed_data():
    if os.getenv("ALLOW_BOOTSTRAP_SEED", "").lower() != "true":
        raise RuntimeError(
            "Bootstrap seed is disabled. Set ALLOW_BOOTSTRAP_SEED=true explicitly."
        )
    admin_password = os.environ["SEED_ADMIN_PASSWORD"]
    teacher_password = os.environ["SEED_TEACHER_PASSWORD"]
    demo_password = os.environ["SEED_DEMO_PASSWORD"]

    async with AsyncSessionLocal() as db:
        print("🌱 Seeding initial data...")

        # 1. Create or get School
        stmt = select(School).where(School.code == "SCH-001")
        res = await db.execute(stmt)
        school = res.scalar_one_or_none()

        if not school:
            school = School(
                name="№1 Орто Мектеп",
                code="SCH-001",
                latitude=42.876500,  # Bishkek center coordinates
                longitude=74.603700,
                allowed_radius_meters=80.0,
                max_accuracy_meters=50.0,
                default_start_time=time(8, 0),
                default_end_time=time(17, 0),
                grace_minutes=5,
                timezone="Asia/Bishkek",
                is_active=True,
            )
            db.add(school)
            await db.flush()
            print(f"  ✓ Created School: {school.name} ({school.id})")
        else:
            print(f"  • School already exists: {school.name}")

        # 2. Create Admin User
        stmt = select(User).where(User.username == "admin")
        res = await db.execute(stmt)
        admin_user = res.scalar_one_or_none()

        if not admin_user:
            admin_user = User(
                username="admin",
                email="admin@school.edu.kg",
                hashed_password=get_password_hash(admin_password),
                full_name="Мектеп Администратору",
                role=UserRole.ADMIN,
                is_active=True,
                is_demo=False,
                school_id=school.id,
            )
            db.add(admin_user)
            await db.flush()
            print("  ✓ Created Admin account (password loaded from environment)")
        else:
            print("  • Admin user already exists")

        # 3. Create Teacher User & Profile
        stmt = select(User).where(User.username == "teacher1")
        res = await db.execute(stmt)
        teacher_user = res.scalar_one_or_none()

        if not teacher_user:
            teacher_user = User(
                username="teacher1",
                email="teacher1@school.edu.kg",
                hashed_password=get_password_hash(teacher_password),
                full_name="Асанов Асан",
                role=UserRole.TEACHER,
                is_active=True,
                is_demo=False,
                school_id=school.id,
            )
            db.add(teacher_user)
            await db.flush()

            teacher_profile = Teacher(
                user_id=teacher_user.id,
                school_id=school.id,
                employee_code="TCH-001",
                phone="+996555123456",
                is_active=True,
            )
            db.add(teacher_profile)
            await db.flush()
            print("  ✓ Created Teacher account (password loaded from environment)")
        else:
            print("  • Teacher user already exists")

        # 5. Create Default Weekly Schedules (Monday to Friday 08:00-17:00, Sat/Sun Day Off)
        for day in range(7):
            stmt = select(WorkSchedule).where(
                WorkSchedule.school_id == school.id,
                WorkSchedule.teacher_id.is_(None),
                WorkSchedule.day_of_week == day,
            )
            res = await db.execute(stmt)
            schedule = res.scalar_one_or_none()

            if not schedule:
                is_weekend = day in [5, 6]
                schedule = WorkSchedule(
                    school_id=school.id,
                    teacher_id=None,
                    day_of_week=day,
                    start_time=time(8, 0),
                    end_time=time(17, 0),
                    grace_minutes=5,
                    is_day_off=is_weekend,
                )
                db.add(schedule)
        print("  ✓ Created Default Work Schedules for School (Mon-Sun)")

        # 6. Create Permanent QR Credential for School
        stmt = select(QrCredential).where(
            QrCredential.school_id == school.id,
            QrCredential.is_active.is_(True),
        )
        res = await db.execute(stmt)
        qr = res.scalar_one_or_none()

        if not qr:
            qr = QrCredential(
                school_id=school.id,
                label="Башкы кире бериш QR",
                is_active=True,
            )
            db.add(qr)
            print("  ✓ Created random School QR Credential")

        await db.commit()

        # The App Review tenant is provisioned by the same code path that
        # scripts/provision_review_tenant.py uses against a live deployment.
        tenant = await review_tenant_service.provision(db, demo_password)
        print(
            "  ✓ App Review demo tenant "
            + ("created" if tenant.created else "already present")
        )
        print("✅ Database seeding complete!")


if __name__ == "__main__":
    asyncio.run(seed_data())
