from datetime import datetime, date, time
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.enums import AttendanceEventType, AttendanceStatus


class QrPayload(BaseModel):
    type: str = "school_attendance"
    school_id: str
    token: str


class AttendanceCheckInRequest(BaseModel):
    school_id: str
    qr_token: str
    latitude: float = Field(..., description="Teacher's current latitude from GPS")
    longitude: float = Field(..., description="Teacher's current longitude from GPS")
    accuracy: float = Field(..., description="GPS accuracy in meters")
    device_info: Optional[str] = None


class AttendanceCheckOutRequest(BaseModel):
    school_id: str
    qr_token: str
    latitude: float
    longitude: float
    accuracy: float
    device_info: Optional[str] = None


class AttendanceEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

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


class DailyAttendanceSummaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

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
