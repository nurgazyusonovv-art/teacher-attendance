from fastapi import APIRouter
from app.api.v1.endpoints import attendance, auth, devices, health, qr, reports, schedules, schools, teachers

api_router = APIRouter()
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(schools.router, prefix="/schools", tags=["Schools"])
api_router.include_router(teachers.router, prefix="/teachers", tags=["Teachers"])
api_router.include_router(schedules.router, prefix="/schedules", tags=["Schedules"])
api_router.include_router(qr.router, prefix="/qr", tags=["QR"])
api_router.include_router(attendance.router, prefix="/attendance", tags=["Attendance"])
api_router.include_router(devices.router, prefix="/devices", tags=["Devices"])
api_router.include_router(reports.router, prefix="/reports", tags=["Reports"])
