import asyncio
import sys
from datetime import time
from pathlib import Path

# Add backend directory to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select
from app.core.security import get_password_hash
from app.db.base_class import Base
from app.db.session import async_engine, AsyncSessionLocal
from app.models.attendance import AttendanceEvent
from app.models.audit import AuditLog
from app.models.daily_attendance import DailyAttendance
from app.models.device import Device
from app.models.enums import UserRole
from app.models.qr import QrCredential
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User
from app.models.schedule import WorkSchedule


async def seed():
    print("=== [1/4] Creating database tables if not exist ===")
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        print("=== [2/4] Seeding School & QR Credential ===")
        # Check if school exists
        school_res = await session.execute(select(School).where(School.code == "SCH-001"))
        school = school_res.scalar_one_or_none()

        if not school:
            school = School(
                name="№1 Орто Мектеп",
                code="SCH-001",
                latitude=42.8746,
                longitude=74.5698,
                allowed_radius_meters=150.0,
                max_accuracy_meters=60.0,
                default_start_time=time(8, 0),
                default_end_time=time(17, 0),
                grace_minutes=15,
                timezone="Asia/Bishkek",
                is_active=True,
            )
            session.add(school)
            await session.commit()
            await session.refresh(school)
            print(f"   Created School: {school.name} (ID: {school.id})")
        else:
            print(f"   School already exists: {school.name} (ID: {school.id})")

        # QR Credential
        qr_res = await session.execute(
            select(QrCredential).where(QrCredential.school_id == school.id, QrCredential.is_active == True) # noqa: E712
        )
        qr = qr_res.scalar_one_or_none()
        if not qr:
            qr = QrCredential(
                school_id=school.id,
                token="school-qr-demo-token-12345",
                label="Башкы кире бериш (Негизги QR)",
                is_active=True,
            )
            session.add(qr)
            await session.commit()
            print("   Created Active QR Credential: school-qr-demo-token-12345")
        else:
            print(f"   QR Credential already exists: {qr.token}")

        print("=== [3/4] Seeding Users (Admin, Teacher, Demo Teacher) ===")

        # 1. Admin User
        admin_res = await session.execute(select(User).where(User.username == "admin"))
        admin = admin_res.scalar_one_or_none()
        if not admin:
            admin = User(
                username="admin",
                email="admin@school.kg",
                full_name="Мектеп Администратору",
                hashed_password=get_password_hash("admin123"),
                role=UserRole.ADMIN,
                is_active=True,
                is_demo=False,
            )
            session.add(admin)
            print("   Created Admin: username='admin', password='admin123'")
        else:
            admin.hashed_password = get_password_hash("admin123")
            print("   Admin already exists: username='admin'")

        # 2. Standard Teacher User
        t1_user_res = await session.execute(select(User).where(User.username == "teacher1"))
        t1_user = t1_user_res.scalar_one_or_none()
        if not t1_user:
            t1_user = User(
                username="teacher1",
                email="teacher1@school.kg",
                full_name="Асанов Асан Асанович",
                hashed_password=get_password_hash("teacher123"),
                role=UserRole.TEACHER,
                is_active=True,
                is_demo=False,
            )
            session.add(t1_user)
            await session.flush()

            t1_teacher = Teacher(
                user_id=t1_user.id,
                school_id=school.id,
                employee_code="TCH-001",
                phone="+996555123456",
                is_active=True,
            )
            session.add(t1_teacher)
            print("   Created Teacher 1: username='teacher1', password='teacher123'")
        else:
            t1_user.hashed_password = get_password_hash("teacher123")
            print("   Teacher 1 already exists: username='teacher1'")

        # 3. Demo Teacher (App Store Reviewer)
        demo_user_res = await session.execute(select(User).where(User.username == "demo_teacher"))
        demo_user = demo_user_res.scalar_one_or_none()
        if not demo_user:
            demo_user = User(
                username="demo_teacher",
                email="demo@school.kg",
                full_name="Демо Мугалим (App Review)",
                hashed_password=get_password_hash("demo123"),
                role=UserRole.TEACHER,
                is_active=True,
                is_demo=True,  # Bypasses geofence distance restrictions
            )
            session.add(demo_user)
            await session.flush()

            demo_teacher = Teacher(
                user_id=demo_user.id,
                school_id=school.id,
                employee_code="DEMO-001",
                phone="+996555999888",
                is_active=True,
            )
            session.add(demo_teacher)
            print("   Created Demo Teacher: username='demo_teacher', password='demo123'")
        else:
            demo_user.hashed_password = get_password_hash("demo123")
            demo_user.is_demo = True
            print("   Demo Teacher already exists: username='demo_teacher'")

        # 4. Weekly Schedules
        print("=== [4/4] Seeding School Weekly Schedules ===")
        sched_res = await session.execute(
            select(WorkSchedule).where(
                WorkSchedule.school_id == school.id,
                WorkSchedule.teacher_id == None, # noqa: E711
            )
        )
        existing_schedules = sched_res.scalars().all()
        if not existing_schedules:
            for day in range(7):
                is_sunday = (day == 6)
                is_saturday = (day == 5)
                end_t = time(14, 0) if is_saturday else time(17, 0)
                schedule = WorkSchedule(
                    school_id=school.id,
                    teacher_id=None,
                    day_of_week=day,
                    start_time=time(8, 0) if not is_sunday else None,
                    end_time=end_t if not is_sunday else None,
                    grace_minutes=15,
                    is_day_off=is_sunday,
                )
                session.add(schedule)
            print("   Created 7-day default school schedule (Mon-Fri 08:00-17:00, Sat 08:00-14:00, Sun off)")
        else:
            print(f"   School schedule already exists ({len(existing_schedules)} days)")

        await session.commit()
        print("\n=======================================================")
        print("🎉 БАРДЫК ТЕСТТИК АККАУНТТАР ИЙГИЛИКТҮҮ ТҮЗҮЛДҮ!")
        print("=======================================================")


if __name__ == "__main__":
    asyncio.run(seed())
