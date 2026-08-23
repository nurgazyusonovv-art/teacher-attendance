from datetime import datetime
from fastapi import APIRouter
from app.core.config import settings
from app.core.timezone import current_time_in_school_timezone
from app.schemas.common import StandardResponse

router = APIRouter()


@router.get("/health", response_model=StandardResponse[dict])
async def health_check():
    """
    Returns API health status, server time in school timezone, and environment metadata.
    """
    server_now = current_time_in_school_timezone()
    return StandardResponse(
        success=True,
        message="Teacher Attendance API is healthy",
        data={
            "status": "healthy",
            "environment": settings.ENVIRONMENT,
            "timezone": settings.TIMEZONE,
            "server_time_iso": server_now.isoformat(),
            "server_time_readable": server_now.strftime("%Y-%m-%d %H:%M:%S %Z"),
        }
    )
