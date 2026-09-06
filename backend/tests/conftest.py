# ruff: noqa: E402
import asyncio
import os
import shutil
import tempfile

# Tests must never inherit a developer or production database URL. Configure an
# isolated SQLite database before importing any application modules/settings.
_TEST_DB_DIR = tempfile.mkdtemp(prefix="teacher-attendance-tests-")
_TEST_DB_PATH = os.path.join(_TEST_DB_DIR, "test.db")
os.environ["ENVIRONMENT"] = "test"
os.environ["DEBUG"] = "False"
os.environ["SECRET_KEY"] = "test-only-secret-key-at-least-32-characters"
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{_TEST_DB_PATH}"
os.environ["SYNC_DATABASE_URL"] = f"sqlite:///{_TEST_DB_PATH}"
import pytest
import pytest_asyncio
from datetime import time
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_password_hash
from app.db.base_class import Base
from app.db.session import AsyncSessionLocal, async_engine
from app.main import app
from app.models.enums import UserRole
from app.models.qr import QrCredential
from app.models.schedule import WorkSchedule
from app.models.school import School
from app.models.teacher import Teacher
from app.models.user import User


async def _create_test_database() -> None:
    async with async_engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        school = School(
            name="№1 Орто Мектеп",
            code="TEST-001",
            latitude=42.8746,
            longitude=74.5698,
            allowed_radius_meters=80,
            max_accuracy_meters=50,
            default_start_time=time(8),
            default_end_time=time(17),
            grace_minutes=5,
            timezone="Asia/Bishkek",
        )
        session.add(school)
        await session.flush()
        admin = User(
            username="admin",
            email="admin@example.com",
            full_name="Test Admin",
            hashed_password=get_password_hash("admin123"),
            role=UserRole.ADMIN,
            school_id=school.id,
        )
        teacher_user = User(
            username="teacher1",
            email="teacher1@example.com",
            full_name="Test Teacher",
            hashed_password=get_password_hash("teacher123"),
            role=UserRole.TEACHER,
            school_id=school.id,
        )
        demo_user = User(
            username="demo_teacher",
            email="demo@example.com",
            full_name="Test Demo Teacher",
            hashed_password=get_password_hash("demo123"),
            role=UserRole.TEACHER,
            is_demo=True,
            school_id=school.id,
        )
        session.add_all([admin, teacher_user, demo_user])
        await session.flush()

        teacher = Teacher(
            user_id=teacher_user.id,
            school_id=school.id,
            employee_code="TEST-TCH-001",
            is_active=True,
        )
        demo_teacher = Teacher(
            user_id=demo_user.id,
            school_id=school.id,
            employee_code="TEST-DEMO-001",
            is_active=True,
        )
        session.add_all([teacher, demo_teacher])
        session.add(QrCredential(school_id=school.id, label="Test QR"))
        for day in range(7):
            session.add(
                WorkSchedule(
                    school_id=school.id,
                    day_of_week=day,
                    start_time=time(8),
                    end_time=time(17),
                    grace_minutes=5,
                    is_day_off=day == 6,
                )
            )
        await session.commit()


@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Create disposable schema and fixtures without touching configured databases."""
    asyncio.run(_create_test_database())
    asyncio.run(async_engine.dispose())
    yield
    asyncio.run(async_engine.dispose())
    shutil.rmtree(_TEST_DB_DIR, ignore_errors=True)


@pytest_asyncio.fixture(autouse=True)
async def cleanup_db_pool():
    yield
    await async_engine.dispose()


@pytest_asyncio.fixture
async def async_client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest_asyncio.fixture
async def db_session() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session


@pytest_asyncio.fixture
async def admin_auth_headers(async_client: AsyncClient) -> dict:
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": "admin123"},
    )
    tokens = response.json()["data"]
    return {"Authorization": f"Bearer {tokens['access_token']}"}


@pytest_asyncio.fixture
async def teacher_auth_headers(async_client: AsyncClient) -> dict:
    response = await async_client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "teacher1", "password": "teacher123"},
    )
    tokens = response.json()["data"]
    return {"Authorization": f"Bearer {tokens['access_token']}"}
