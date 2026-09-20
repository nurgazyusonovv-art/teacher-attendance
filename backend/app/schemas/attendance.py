from datetime import date, datetime, time
from typing import List, Optional, Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.timezone import to_school_timezone
from app.models.enums import AttendanceEventType, AttendanceStatus
from app.schemas.lesson_delay import LessonDelayRead


class AttendanceScanRequest(BaseModel):
    school_id: str = Field(..., min_length=36, max_length=36, description="Мектептин IDси")
    qr_token: str = Field(..., min_length=16, max_length=128, description="Сканерленген QR токен")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS кеңдик")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS узундук")
    accuracy: float = Field(..., ge=0.0, description="GPS тактыгы (метр)")
    device_info: Optional[str] = Field(None, max_length=255, description="Түзмөктүн маалыматы")
    device_id: Optional[str] = Field(
        None,
        min_length=3,
        max_length=255,
        description="Катталган түзмөктүн идентификатору (device binding күйгүзүлгөндө талап кылынат)",
    )



class SchoolLocalTimes(BaseModel):
    """Emits attendance timestamps in the school's own timezone.

    The columns are TIMESTAMPTZ, so a value read back from PostgreSQL arrives
    as UTC no matter what timezone it was written in. Serialized as-is it
    becomes `...Z`, and every client would then need the school's offset just
    to show a wall clock. Normalizing here keeps the documented contract:
    a time in an attendance response is the time at the school.
    """

    # Callers pass the school's zone; never part of the response body.
    school_timezone: Optional[str] = Field(default=None, exclude=True)

    @model_validator(mode="after")
    def _localize_times(self) -> "SchoolLocalTimes":
        for field in ("check_in_time", "check_out_time"):
            value = getattr(self, field, None)
            if value is not None:
                setattr(self, field, to_school_timezone(value, self.school_timezone))
        return self


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


class DailyAttendanceRead(SchoolLocalTimes):
    display_status: Optional[str] = None
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


class DailyAttendancePage(BaseModel):
    """Paged school-wide history, so a report is one request instead of one
    per teacher."""

    items: List[DailyAttendanceRead]
    total: int
    skip: int
    limit: int


class TodayStatusResponse(SchoolLocalTimes):
    school_name: Optional[str] = None
    date: date
    # The school's offset from UTC right now, so the client renders and
    # expires its cache against the school's day rather than guessing.
    utc_offset_minutes: int = 0
    # The school's clock at the moment of the response. A teacher deciding
    # whether they are late must not be reading their phone's clock, which
    # can be minutes off; the app ticks forward from this instead.
    server_time: Optional[datetime] = None
    display_status: Literal['ON_TIME', 'LATE', 'ABSENT', 'EXCUSED', 'DAY_OFF', 'PENDING', 'NO_SCHEDULE']
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


class AttendanceResetRequest(BaseModel):
    confirmation: str = Field(..., min_length=10, max_length=32)
