"""add_subject_and_lesson_delays

Revision ID: f7129841abcd
Revises: 2cd22ee44e24
Create Date: 2026-08-26 16:35:00.000000+06:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f7129841abcd'
down_revision: Union[str, None] = '2cd22ee44e24'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add subject column to teachers table if not present
    try:
        op.add_column('teachers', sa.Column('subject', sa.String(length=100), nullable=True))
    except Exception:
        pass

    # 2. Create lesson_delays table if not present
    try:
        op.create_table('lesson_delays',
            sa.Column('id', sa.String(length=36), nullable=False),
            sa.Column('teacher_id', sa.String(length=36), nullable=False),
            sa.Column('school_id', sa.String(length=36), nullable=False),
            sa.Column('date', sa.Date(), nullable=False),
            sa.Column('lesson_number', sa.Integer(), nullable=False),
            sa.Column('delay_minutes', sa.Integer(), nullable=False),
            sa.Column('reason', sa.String(length=255), nullable=True),
            sa.Column('recorded_by_user_id', sa.String(length=36), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
            sa.ForeignKeyConstraint(['recorded_by_user_id'], ['users.id'], ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['teacher_id'], ['teachers.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_lesson_delays_date'), 'lesson_delays', ['date'], unique=False)
        op.create_index(op.f('ix_lesson_delays_school_id'), 'lesson_delays', ['school_id'], unique=False)
        op.create_index(op.f('ix_lesson_delays_teacher_id'), 'lesson_delays', ['teacher_id'], unique=False)
    except Exception:
        pass


def downgrade() -> None:
    try:
        op.drop_table('lesson_delays')
    except Exception:
        pass
    try:
        op.drop_column('teachers', 'subject')
    except Exception:
        pass
