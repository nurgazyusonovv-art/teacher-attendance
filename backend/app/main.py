from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.errors import AppException, ErrorCode
from app.api.v1.api import api_router
from app.db.session import async_engine
from app.db.base_class import Base
import app.models  # Ensure all models are registered with Base


import asyncio
from app.db.auto_migrate import init_and_migrate_db
from app.services.telegram_service import TelegramService


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure tables exist, missing columns are added, and master data seeded safely
    try:
        await init_and_migrate_db()
    except Exception as e:
        print(f"Error during startup database auto-migration: {e}")

    # Start automated background daily Telegram report scheduler
    scheduler_task = asyncio.create_task(TelegramService.start_scheduler())

    yield

    # Shutdown
    scheduler_task.cancel()
    try:
        await scheduler_task
    except asyncio.CancelledError:
        pass
    except Exception:
        pass

    await async_engine.dispose()


app = FastAPI(
    title=settings.PROJECT_NAME,
    description="School Employee Attendance System API (QR + GPS verification)",
    version="1.0.0",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    lifespan=lifespan,
)

# Set CORS middleware
if settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


# Exception handler for domain AppException
@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "code": exc.code.value if hasattr(exc.code, "value") else str(exc.code),
            "message": exc.message,
            "details": exc.details,
        },
    )


# Exception handler for Pydantic / FastAPI validation errors
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    formatted_errors = {}
    for err in errors:
        field = ".".join([str(loc) for loc in err.get("loc", []) if loc != "body"])
        formatted_errors[field or "general"] = err.get("msg", "Invalid input")

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "code": ErrorCode.VALIDATION_ERROR.value,
            "message": "Input validation failed. Please check the submitted fields.",
            "details": formatted_errors,
        },
    )


# Generic catch-all exception handler
@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    import traceback
    # Log exception internally (never expose internal trace to client as per AGENTS.md #10)
    print(f"Unhandled server error: {exc}")
    traceback.print_exc()

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "code": ErrorCode.INTERNAL_SERVER_ERROR.value,
            "message": "An unexpected server error occurred. Please try again later.",
            "details": {},
        },
    )


# Include API v1 router
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Root"])
async def root():
    return {
        "project": settings.PROJECT_NAME,
        "version": "1.0.0",
        "docs": f"{settings.API_V1_STR}/docs",
    }
