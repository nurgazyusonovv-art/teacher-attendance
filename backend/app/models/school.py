import uuid
from datetime import datetime, time
from typing import List, Optional, TYPE_CHECKING
from sqlalchemy import String, Float, Integer, Boolean, Time, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base_class import Base

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.qr import QrCredential
    from app.models.schedule import WorkSchedule
    from app.models.attendance import AttendanceEvent
    from app.models.daily_attendance import DailyAttendance
    from app.models.audit import AuditLog


class School(Base):
    __tablename__ = "schools"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    
    # Location Geofence Settings
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    allowed_radius_meters: Mapped[float] = mapped_column(Float, default=80.0, nullable=False)
    max_accuracy_meters: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    
    # Time and Schedule Settings
    default_start_time: Mapped[time] = mapped_column(Time, default=time(8, 0), nullable=False)
    default_end_time: Mapped[time] = mapped_column(Time, default=time(17, 0), nullable=False)
    grace_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    timezone: Mapped[str] = mapped_column(String(50), default="Asia/Bishkek", nullable=False)
    
    # Telegram Integration Settings
    telegram_bot_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    telegram_chat_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    telegram_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    telegram_report_time: Mapped[Optional[time]] = mapped_column(Time, default=time(17, 30), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    teachers: Mapped[List["Teacher"]] = relationship("Teacher", back_populates="school", cascade="all, delete-orphan")
    qr_credentials: Mapped[List["QrCredential"]] = relationship("QrCredential", back_populates="school", cascade="all, delete-orphan")
    schedules: Mapped[List["WorkSchedule"]] = relationship("WorkSchedule", back_populates="school", cascade="all, delete-orphan")
    attendance_events: Mapped[List["AttendanceEvent"]] = relationship("AttendanceEvent", back_populates="school")
    daily_attendances: Mapped[List["DailyAttendance"]] = relationship("DailyAttendance", back_populates="school")
    audit_logs: Mapped[List["AuditLog"]] = relationship("AuditLog", back_populates="school")
