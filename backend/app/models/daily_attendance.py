import uuid
from datetime import datetime, date
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, Integer, Boolean, Date, DateTime, ForeignKey, UniqueConstraint, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base_class import Base
from app.models.enums import AttendanceStatus

if TYPE_CHECKING:
    from app.models.teacher import Teacher
    from app.models.school import School
    from app.models.user import User


class DailyAttendance(Base):
    """
    Summarized daily attendance status per teacher per day.
    Aggregates check-in, check-out, status, late minutes, and manual corrections.
    """
    __tablename__ = "daily_attendance"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    teacher_id: Mapped[str] = mapped_column(String(36), ForeignKey("teachers.id", ondelete="CASCADE"), index=True, nullable=False)
    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id", ondelete="CASCADE"), index=True, nullable=False)
    
    date: Mapped[date] = mapped_column(Date, index=True, nullable=False)
    check_in_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    check_out_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    status: Mapped[AttendanceStatus] = mapped_column(
        SAEnum(AttendanceStatus, name="daily_attendance_status_enum", native_enum=False),
        default=AttendanceStatus.ON_TIME,
        nullable=False,
        index=True
    )
    late_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    worked_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    
    # Manual Correction Audit fields (AGENTS.md #18: admin correction requires audit trail)
    is_manually_corrected: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    correction_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    corrected_by_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    teacher: Mapped["Teacher"] = relationship("Teacher", back_populates="daily_attendances")
    school: Mapped["School"] = relationship("School", back_populates="daily_attendances")
    corrected_by: Mapped[Optional["User"]] = relationship("User", foreign_keys=[corrected_by_id])

    __table_args__ = (
        UniqueConstraint("teacher_id", "date", name="uq_teacher_date_attendance"),
    )
