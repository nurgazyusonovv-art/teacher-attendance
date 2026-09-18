"""mark the isolated App Review demo school

The demo account used to skip the geofence through an `if not user.is_demo`
branch inside the production check-in path. That branch is gone, so the
reviewer school now carries its own worldwide radius instead — the security
code is identical for every school, and only this row's geofence is wide.

The flag is what keeps that safe: a school marked here may never hold a real
teacher, which is enforced in AttendanceService.

Revision ID: b8c04fa2e008
Revises: a7b93ef1d007
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b8c04fa2e008"
down_revision: Union[str, None] = "a7b93ef1d007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Half of Earth's circumference is ~20 040 km, so this covers every point.
WORLDWIDE_RADIUS_METERS = 20_100_000.0
# A simulator or a desktop browser reports very coarse positions.
REVIEW_MAX_ACCURACY_METERS = 100_000.0


def upgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.add_column(
            sa.Column(
                "is_review_demo",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )

    # Restore the promise in docs/APP_STORE_GUIDE.md for the existing demo row.
    op.execute(
        sa.text(
            "UPDATE schools SET is_review_demo = true, "
            "allowed_radius_meters = :radius, max_accuracy_meters = :accuracy "
            "WHERE code = 'DEMO-001'"
        ).bindparams(
            radius=WORLDWIDE_RADIUS_METERS, accuracy=REVIEW_MAX_ACCURACY_METERS
        )
    )


def downgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.drop_column("is_review_demo")
