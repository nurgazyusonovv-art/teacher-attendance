"""add school attendance_start_date

Replaces the hardcoded 2026-09-07 absence epoch with a per-school setting.
Existing rows are backfilled with that same date so deployed behaviour is
unchanged; new schools fall back to their creation date.

Revision ID: e35f1cb7d005
Revises: d24f5ca6e004
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "e35f1cb7d005"
down_revision: Union[str, None] = "d24f5ca6e004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


LEGACY_ABSENCE_EPOCH = "2026-09-07"


def upgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.add_column(
            sa.Column("attendance_start_date", sa.Date(), nullable=True)
        )
    op.execute(
        sa.text(
            "UPDATE schools SET attendance_start_date = :epoch "
            "WHERE attendance_start_date IS NULL"
        ).bindparams(epoch=LEGACY_ABSENCE_EPOCH)
    )


def downgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.drop_column("attendance_start_date")
