"""School-scoped leave requests with audited review."""
from alembic import op
import sqlalchemy as sa

revision = 'd24f5ca6e004'
down_revision = 'c13e4bf5d003'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('leave_requests',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('school_id', sa.String(36), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False),
        sa.Column('teacher_id', sa.String(36), sa.ForeignKey('teachers.id', ondelete='CASCADE'), nullable=False),
        sa.Column('target_date', sa.Date(), nullable=False),
        sa.Column('reason', sa.String(500), nullable=False),
        sa.Column('status', sa.String(16), nullable=False),
        sa.Column('reviewed_by_id', sa.String(36), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('reviewed_at', sa.DateTime(timezone=True)),
        sa.Column('decision_reason', sa.String(500)),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('teacher_id', 'target_date', name='uq_leave_teacher_date'),
        sa.CheckConstraint("status IN ('PENDING','APPROVED','REJECTED')", name='ck_leave_status'))
    for column in ('school_id', 'teacher_id', 'target_date'):
        op.create_index(f'ix_leave_requests_{column}', 'leave_requests', [column])


def downgrade():
    op.drop_table('leave_requests')
