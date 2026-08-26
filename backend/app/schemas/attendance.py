from datetime import date, datetime, time
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import AttendanceEventType, AttendanceStatus
from app.schemas.lesson_delay import LessonDelayRead


class AttendanceScanRequest(BaseModel):
    school_id: str = Field(..., description="Мектептин IDси")
    qr_token: str = Field(..., description="Сканерленген QR токен")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS кеңдик")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS узундук")
    accuracy: float = Field(..., ge=0.0, description="GPS тактыгы (метр)")
    device_info: Optional[str] = Field(None, description="Түзмөктүн маалыматы")


class AttendanceEventRead(BaseModel):
    id: str
    teacher_id: str
    school_id: str
    event_type: AttendanceEventType
    event_time: datetime
    status: AttendanceStatus
    late_minutes: int
    distance_meters: float
    location_accuracy_meters: float
    location_verified: bool
    qr_verified: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DailyAttendanceRead(BaseModel):
    id: str
    teacher_id: str
    school_id: str
    date: date
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    status: AttendanceStatus
    late_minutes: int
    worked_minutes: int
    is_manually_corrected: bool
    correction_reason: Optional[str] = None
    teacher_name: Optional[str] = None
    employee_code: Optional[str] = None
    phone_number: Optional[str] = None
    subject: Optional[str] = None
    lesson_delays: List[LessonDelayRead] = []
    lesson_late_minutes: int = 0
    total_late_minutes: int = 0

    model_config = ConfigDict(from_attributes=True)


class TodayStatusResponse(BaseModel):
    date: date
    has_checked_in: bool
    has_checked_out: bool
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    status: Optional[AttendanceStatus] = None
    late_minutes: int = 0
    worked_minutes: int = 0
    scheduled_start: Optional[time] = None
    scheduled_end: Optional[time] = None
    is_day_off: bool = False
    lesson_delays: List[LessonDelayRead] = []
    lesson_late_minutes: int = 0
    total_late_minutes: int = 0


class AdminDashboardSummary(BaseModel):
    total_teachers: int
    checked_in_count: int
    on_time_count: int
    late_count: int
    not_checked_in_count: int
    date: date
    records: List[DailyAttendanceRead]


class ManualCorrectionRequest(BaseModel):
    daily_attendance_id: Optional[str] = None
    teacher_id: str
    target_date: date
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    status: AttendanceStatus
    reason: str = Field(..., min_length=5, max_length=500, description="Оңдоонун себеби (сөзсүз)")
