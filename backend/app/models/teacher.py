import uuid
from datetime import datetime
from typing import Optional, List, TYPE_CHECKING
from sqlalchemy import String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base_class import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.school import School
    from app.models.schedule import WorkSchedule
    from app.models.attendance import AttendanceEvent
    from app.models.daily_attendance import DailyAttendance
    from app.models.lesson_delay import LessonDelay


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id", ondelete="CASCADE"), index=True, nullable=False)
    employee_code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    subject: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="teacher_profile")
    school: Mapped["School"] = relationship("School", back_populates="teachers")
    schedules: Mapped[List["WorkSchedule"]] = relationship("WorkSchedule", back_populates="teacher", cascade="all, delete-orphan")
    attendance_events: Mapped[List["AttendanceEvent"]] = relationship("AttendanceEvent", back_populates="teacher")
    daily_attendances: Mapped[List["DailyAttendance"]] = relationship("DailyAttendance", back_populates="teacher")
    lesson_delays: Mapped[List["LessonDelay"]] = relationship("LessonDelay", back_populates="teacher", cascade="all, delete-orphan")
