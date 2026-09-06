"""add school Telegram settings

Revision ID: b02d3af4c002
Revises: a91c7d25f001
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b02d3af4c002"
down_revision: Union[str, None] = "a91c7d25f001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.add_column(
            sa.Column("telegram_bot_token", sa.String(length=255), nullable=True)
        )
        batch_op.add_column(
            sa.Column("telegram_chat_id", sa.String(length=100), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                "telegram_enabled",
                sa.Boolean(),
                nullable=False,
                server_default=sa.false(),
            )
        )
        batch_op.add_column(
            sa.Column(
                "telegram_report_time",
                sa.Time(),
                nullable=True,
                server_default=sa.text("'17:30:00'"),
            )
        )
        batch_op.add_column(
            sa.Column("last_telegram_report_sent_date", sa.Date(), nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("schools") as batch_op:
        batch_op.drop_column("last_telegram_report_sent_date")
        batch_op.drop_column("telegram_report_time")
        batch_op.drop_column("telegram_enabled")
        batch_op.drop_column("telegram_chat_id")
        batch_op.drop_column("telegram_bot_token")
