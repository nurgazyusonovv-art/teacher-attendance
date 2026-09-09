import uuid
from datetime import date, datetime
from typing import Optional
from sqlalchemy import String, Date, DateTime, ForeignKey, UniqueConstraint, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from app.db.base_class import Base


class LeaveRequest(Base):
    __tablename__ = 'leave_requests'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    school_id: Mapped[str] = mapped_column(String(36), ForeignKey('schools.id', ondelete='CASCADE'), index=True)
    teacher_id: Mapped[str] = mapped_column(String(36), ForeignKey('teachers.id', ondelete='CASCADE'), index=True)
    target_date: Mapped[date] = mapped_column(Date, index=True)
    reason: Mapped[str] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(16), default='PENDING')
    reviewed_by_id: Mapped[Optional[str]] = mapped_column(String(36), ForeignKey('users.id', ondelete='SET NULL'))
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    decision_reason: Mapped[Optional[str]] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    __table_args__ = (
        UniqueConstraint('teacher_id', 'target_date', name='uq_leave_teacher_date'),
        CheckConstraint("status IN ('PENDING','APPROVED','REJECTED')", name='ck_leave_status'),
    )
