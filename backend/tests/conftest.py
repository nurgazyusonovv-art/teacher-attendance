import asyncio
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import AsyncSessionLocal, async_engine
from app.db.auto_migrate import init_and_migrate_db
from app.main import app


@pytest.fixture(scope="session", autouse=True)
def setup_test_database():
    """Ensure database schema and initial seed data exist before running test suite."""
    asyncio.run(init_and_migrate_db())
    asyncio.run(async_engine.dispose())


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
