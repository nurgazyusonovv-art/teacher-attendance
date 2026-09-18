"""device binding: approval lifecycle and per-school switch

Adds the approval state a registered device needs before it may record
attendance, plus the per-school switch that turns enforcement on. Existing
devices are marked APPROVED so nobody is locked out by the upgrade, and the
switch starts off so deployed app versions that send no device id keep working.

Revision ID: f46a2dc8e006
Revises: e35f1cb7d005
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f46a2dc8e006"
down_revision: Union[str, None] = "e35f1cb7d005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("devices") as batch_op:
        batch_op.add_column(
            sa.Column(
                "status",
                sa.Enum(
                    "PENDING",
                    "APPROVED",
                    "REVOKED",
                    name="device_status_enum",
                    native_enum=False,
                ),
                nullable=False,
                server_default="APPROVED",
            )
        )
        batch_op.add_column(
            sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                "approved_by_id",
                sa.String(length=36),
                sa.ForeignKey(
                    "users.id",
                    ondelete="SET NULL",
                    name="fk_devices_approved_by_id_users",
                ),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True)
        )
    op.create_index("ix_devices_status", "devices", ["status"])

    # Devices registered before approval existed stay usable.
    op.execute(
        sa.text(
            "UPDATE devices SET status = 'APPROVED' "
            "WHERE status IS NULL OR status = ''"
        )
    )
    op.execute(sa.text("UPDATE devices SET status = 'REVOKED' WHERE is_active = false"))

    with op.batch_alter_table("schools") as batch_op:
        batch_op.add_column(
            sa.Column(
                "device_binding_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )


def downgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.drop_column("device_binding_enabled")
    op.drop_index("ix_devices_status", table_name="devices")
    with op.batch_alter_table("devices") as batch_op:
        batch_op.drop_column("revoked_at")
        batch_op.drop_column("approved_by_id")
        batch_op.drop_column("approved_at")
        batch_op.drop_column("status")
