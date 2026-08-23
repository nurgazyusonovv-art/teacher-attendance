import uuid
from datetime import datetime
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, Integer, Float, Boolean, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base_class import Base
from app.models.enums import AttendanceEventType, AttendanceStatus

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.school import School


class AttendanceEvent(Base):
    """
    Records raw check-in and check-out events verified by QR and GPS geofence.
    CRITICAL RULE (AGENTS.md #6, #9): Do NOT store raw latitude/longitude coordinates here.
    Store only verification metrics (distance, accuracy, verified flags).
    """
    __tablename__ = "attendance_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    teacher_id: Mapped[str] = mapped_column(String(36), ForeignKey("teachers.id", ondelete="CASCADE"), index=True, nullable=False)
    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id", ondelete="CASCADE"), index=True, nullable=False)
    
    event_type: Mapped[AttendanceEventType] = mapped_column(
        SAEnum(AttendanceEventType, name="attendance_event_type_enum", native_enum=False),
        nullable=False,
        index=True
    )
    # Server-side authoritative timestamp (Asia/Bishkek)
    event_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    
    status: Mapped[AttendanceStatus] = mapped_column(
        SAEnum(AttendanceStatus, name="attendance_status_enum", native_enum=False),
        default=AttendanceStatus.ON_TIME,
        nullable=False,
        index=True
    )
    late_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    
    # Location verification metadata (No raw GPS lat/lng!)
    distance_meters: Mapped[float] = mapped_column(Float, nullable=False)
    location_accuracy_meters: Mapped[float] = mapped_column(Float, nullable=False)
    location_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    qr_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    
    device_info: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    teacher: Mapped["Teacher"] = relationship("Teacher", back_populates="attendance_events")
    school: Mapped["School"] = relationship("School", back_populates="attendance_events")
