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
    # Older production releases created these objects at startup without
    # advancing Alembic. Adopt compatible existing objects without losing data.
    inspector = sa.inspect(op.get_bind())
    if 'subject' not in {c['name'] for c in inspector.get_columns('teachers')}:
        op.add_column('teachers', sa.Column('subject', sa.String(length=100), nullable=True))
    if inspector.has_table('lesson_delays'):
        required = {'id', 'teacher_id', 'school_id', 'date', 'lesson_number',
                    'delay_minutes', 'reason', 'recorded_by_user_id', 'created_at', 'updated_at'}
        if not required.issubset({c['name'] for c in inspector.get_columns('lesson_delays')}):
            raise RuntimeError('Existing lesson_delays schema needs reconciliation')
        indexes = {i['name'] for i in inspector.get_indexes('lesson_delays')}
        for column in ('date', 'school_id', 'teacher_id'):
            name = f'ix_lesson_delays_{column}'
            if name not in indexes:
                op.create_index(name, 'lesson_delays', [column], unique=False)
        return

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


def downgrade() -> None:
    op.drop_table('lesson_delays')
    op.drop_column('teachers', 'subject')
