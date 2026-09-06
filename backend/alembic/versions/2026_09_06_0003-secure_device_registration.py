"""secure device registration uniqueness

Revision ID: c13e4bf5d003
Revises: b02d3af4c002
"""

from typing import Sequence, Union

from alembic import op


revision: str = "c13e4bf5d003"
down_revision: Union[str, None] = "b02d3af4c002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "DELETE FROM devices WHERE id NOT IN "
        "(SELECT MIN(id) FROM devices GROUP BY user_id, device_id)"
    )
    with op.batch_alter_table("devices") as batch_op:
        batch_op.create_unique_constraint(
            "uq_devices_user_device", ["user_id", "device_id"]
        )


def downgrade() -> None:
    with op.batch_alter_table("devices") as batch_op:
        batch_op.drop_constraint("uq_devices_user_device", type_="unique")
