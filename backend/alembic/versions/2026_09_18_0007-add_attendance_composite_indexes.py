"""composite indexes for the attendance read paths

Every hot query filters on a pair of columns that were only indexed
separately: the dashboard on (school_id, date), a teacher's history on
(teacher_id, date), the school report on the same pairs for lesson delays,
and the audit/event timeline on (teacher_id, event_time).

Revision ID: a7b93ef1d007
Revises: f46a2dc8e006
"""

from typing import Sequence, Union

from alembic import op


revision: str = "a7b93ef1d007"
down_revision: Union[str, None] = "f46a2dc8e006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_INDEXES = (
    ("ix_daily_attendance_school_date", "daily_attendance", ["school_id", "date"]),
    ("ix_daily_attendance_teacher_date", "daily_attendance", ["teacher_id", "date"]),
    ("ix_attendance_events_teacher_time", "attendance_events", ["teacher_id", "event_time"]),
    ("ix_lesson_delays_school_date", "lesson_delays", ["school_id", "date"]),
    ("ix_lesson_delays_teacher_date", "lesson_delays", ["teacher_id", "date"]),
    ("ix_audit_logs_school_action_created", "audit_logs", ["school_id", "action", "created_at"]),
)


def upgrade() -> None:
    for name, table, columns in _INDEXES:
        op.create_index(name, table, columns)


def downgrade() -> None:
    for name, table, _ in reversed(_INDEXES):
        op.drop_index(name, table_name=table)
