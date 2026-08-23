import uuid
from datetime import datetime, time
from typing import Optional, TYPE_CHECKING
from sqlalchemy import String, Integer, Boolean, Time, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from app.db.base_class import Base

if TYPE_CHECKING:
    from app.models.school import School
    from app.models.teacher import Teacher


class WorkSchedule(Base):
    __tablename__ = "work_schedules"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    school_id: Mapped[str] = mapped_column(String(36), ForeignKey("schools.id", ondelete="CASCADE"), index=True, nullable=False)
    teacher_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("teachers.id", ondelete="CASCADE"), index=True, nullable=True)
    
    # 0 = Monday, 1 = Tuesday, ..., 6 = Sunday
    day_of_week: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    grace_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_day_off: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    school: Mapped["School"] = relationship("School", back_populates="schedules")
    teacher: Mapped[Optional["Teacher"]] = relationship("Teacher", back_populates="schedules")

    __table_args__ = (
        UniqueConstraint("school_id", "teacher_id", "day_of_week", name="uq_school_teacher_day"),
    )
