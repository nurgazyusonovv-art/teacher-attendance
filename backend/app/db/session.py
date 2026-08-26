from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Engine configuration for PostgreSQL (Supabase pooler / Direct) or SQLite fallback
is_postgres = "postgres" in settings.DATABASE_URL

async_connect_args = {}
sync_connect_args = {}

if is_postgres:
    async_connect_args = {
        "statement_cache_size": 0,
        "ssl": "require",
    }
    sync_connect_args = {
        "sslmode": "require",
    }

from sqlalchemy.pool import NullPool

pool_kwargs = {}
if not is_postgres:
    pool_kwargs["poolclass"] = NullPool

# Async Engine for FastAPI async requests (Powered by asyncpg)
async_engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True,
    connect_args=async_connect_args,
    pool_pre_ping=True,
    **pool_kwargs,
)

AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
)

# Synchronous Engine for Alembic migrations or sync operations (Lazy/Safe)
sync_engine = None
SyncSessionLocal = None

try:
    sync_engine = create_engine(
        settings.SYNC_DATABASE_URL,
        echo=False,
        future=True,
        connect_args=sync_connect_args,
        pool_pre_ping=True,
    )
    SyncSessionLocal = sessionmaker(
        autocommit=False,
        autoflush=False,
        bind=sync_engine,
    )
except Exception as e:
    print(f"Warning: sync_engine initialization deferred: {e}")


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency that provides an async database session per request."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
