import logging
from datetime import time
from sqlalchemy import select, text
from app.db.base_class import Base
from app.db.session import async_engine, AsyncSessionLocal
from app.models.school import School
from app.models.qr import QrCredential
from app.models.user import User
from app.models.teacher import Teacher
from app.models.schedule import WorkSchedule
from app.models.enums import UserRole
from app.core.security import get_password_hash
import app.models  # noqa: F401 - Register all models with Base.metadata

logger = logging.getLogger("auto_migrate")


async def init_and_migrate_db():
    """
    Ensures that all database tables and newly added columns exist in both
    PostgreSQL (Render/Supabase) and SQLite, and safely seeds initial system
    data (School, Admin, Schedules) if not already present, preserving all
    existing user and attendance data.
    """
    logger.info("Starting database auto-migration and schema verification...")

    # 1. Create all missing tables (including lesson_delays, daily_attendance, etc.)
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

        # 2. Add newly introduced columns to existing tables safely
        # Column: teachers.subject
        try:
            await conn.execute(text("ALTER TABLE teachers ADD COLUMN IF NOT EXISTS subject VARCHAR(100);"))
        except Exception:
            try:
                await conn.execute(text("ALTER TABLE teachers ADD COLUMN subject VARCHAR(100);"))
            except Exception:
                pass  # Column already exists

        # Columns: schools.telegram_*
        for col_def, col_def_sqlite in [
            ("telegram_bot_token VARCHAR(255)", "telegram_bot_token VARCHAR(255)"),
            ("telegram_chat_id VARCHAR(100)", "telegram_chat_id VARCHAR(100)"),
            ("telegram_enabled BOOLEAN DEFAULT FALSE", "telegram_enabled BOOLEAN DEFAULT 0"),
            ("telegram_report_time TIME DEFAULT '17:30:00'", "telegram_report_time TIME"),
        ]:
            col_name = col_def.split()[0]
            try:
                await conn.execute(text(f"ALTER TABLE schools ADD COLUMN IF NOT EXISTS {col_def};"))
            except Exception:
                try:
                    await conn.execute(text(f"ALTER TABLE schools ADD COLUMN {col_def_sqlite};"))
                except Exception:
                    pass

    # 3. Seed master data if table records are missing (Idempotent)
    async with AsyncSessionLocal() as session:
        # Check / Create default School
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
            logger.info(f"Created default school: {school.name}")
        
        # Check / Create QR credential
        qr_res = await session.execute(
            select(QrCredential).where(QrCredential.school_id == school.id, QrCredential.is_active == True)  # noqa: E712
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
            logger.info("Created default QR credential: school-qr-demo-token-12345")

        # Check / Create / Upgrade Admin User
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
            await session.commit()
            logger.info("Created default Admin: username='admin'")
        elif admin.hashed_password.startswith("$argon2"):
            admin.hashed_password = get_password_hash("admin123")
            await session.commit()
            logger.info("Migrated Admin password to standard bcrypt")

        # Check / Create / Upgrade Teacher 1
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
                subject="Математика",
                is_active=True,
            )
            session.add(t1_teacher)
            await session.commit()
            logger.info("Created default Teacher 1: username='teacher1'")
        elif t1_user.hashed_password.startswith("$argon2"):
            t1_user.hashed_password = get_password_hash("teacher123")
            await session.commit()
            logger.info("Migrated Teacher 1 password to standard bcrypt")

        # Check / Create / Upgrade Demo Teacher
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
                is_demo=True,
            )
            session.add(demo_user)
            await session.flush()

            demo_teacher = Teacher(
                user_id=demo_user.id,
                school_id=school.id,
                employee_code="DEMO-001",
                phone="+996555999888",
                subject="Информатика",
                is_active=True,
            )
            session.add(demo_teacher)
            await session.commit()
            logger.info("Created Demo Teacher: username='demo_teacher'")
        elif demo_user.hashed_password.startswith("$argon2"):
            demo_user.hashed_password = get_password_hash("demo123")
            await session.commit()
            logger.info("Migrated Demo Teacher password to standard bcrypt")

        # Check / Create School Schedules
        sched_res = await session.execute(
            select(WorkSchedule).where(
                WorkSchedule.school_id == school.id,
                WorkSchedule.teacher_id == None,  # noqa: E711
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
            await session.commit()
            logger.info("Created default 7-day school schedule")

    logger.info("Database auto-migration completed successfully.")
