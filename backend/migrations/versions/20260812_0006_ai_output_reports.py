"""Add privacy-minimized AI output reports.

Revision ID: 20260812_0006
Revises: 20260727_0005
Create Date: 2026-08-12
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260812_0006"
down_revision: str | None = "20260727_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create a content-free moderation intake ledger."""
    op.create_table(
        "ai_output_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("conversation_id", sa.Uuid(), nullable=False),
        sa.Column("response_id", sa.Uuid(), nullable=False),
        sa.Column("category", sa.String(length=40), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "category IN ('harmful_or_unsafe', 'harassing_or_hateful', "
            "'sexual_content', 'deceptive_or_manipulative', 'other')",
            name=op.f("ck_ai_output_reports_category"),
        ),
        sa.CheckConstraint(
            "status IN ('received', 'reviewed', 'actioned', 'dismissed')",
            name=op.f("ck_ai_output_reports_status"),
        ),
        sa.ForeignKeyConstraint(
            ["conversation_id"],
            ["conversations.id"],
            name=op.f("fk_ai_output_reports_conversation_id_conversations"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_ai_output_reports_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_output_reports")),
        sa.UniqueConstraint(
            "user_id",
            "response_id",
            name=op.f("uq_ai_output_reports_user_id"),
        ),
    )
    op.create_index(
        "ix_ai_output_reports_status_created",
        "ai_output_reports",
        ["status", "created_at"],
    )
    op.create_index(
        "ix_ai_output_reports_category_created",
        "ai_output_reports",
        ["category", "created_at"],
    )


def downgrade() -> None:
    """Remove report metadata without touching conversations."""
    op.drop_index("ix_ai_output_reports_category_created", table_name="ai_output_reports")
    op.drop_index("ix_ai_output_reports_status_created", table_name="ai_output_reports")
    op.drop_table("ai_output_reports")
