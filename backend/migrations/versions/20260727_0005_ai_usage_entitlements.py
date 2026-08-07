"""Add content-free entitlement and AI usage ledgers.

Revision ID: 20260727_0005
Revises: 20260715_0004
Create Date: 2026-07-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260727_0005"
down_revision: str | None = "20260715_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add server-owned paid entitlements and atomic AI usage records."""
    op.create_table(
        "subscription_entitlements",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("plan_code", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("storefront", sa.String(length=16), nullable=False),
        sa.Column("transaction_reference_hash", sa.String(length=64), nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "verified_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
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
            "plan_code IN ('plus')", name=op.f("ck_subscription_entitlements_plan_code")
        ),
        sa.CheckConstraint(
            "status IN ('active', 'grace', 'expired', 'revoked')",
            name=op.f("ck_subscription_entitlements_status"),
        ),
        sa.CheckConstraint(
            "storefront IN ('apple', 'google', 'admin')",
            name=op.f("ck_subscription_entitlements_storefront"),
        ),
        sa.CheckConstraint(
            "current_period_end > current_period_start",
            name=op.f("ck_subscription_entitlements_period_order"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_subscription_entitlements_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_subscription_entitlements")),
        sa.UniqueConstraint(
            "storefront",
            "transaction_reference_hash",
            name=op.f("uq_subscription_entitlements_storefront"),
        ),
    )
    op.create_index(
        "ix_subscription_entitlements_user_period",
        "subscription_entitlements",
        ["user_id", "current_period_end"],
    )

    op.create_table(
        "ai_usage_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("conversation_id", sa.Uuid(), nullable=True),
        sa.Column("allowance_kind", sa.String(length=40), nullable=False),
        sa.Column("idempotency_key", sa.String(length=64), nullable=False),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("plan_code", sa.String(length=16), nullable=False),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("window_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("model_identifier", sa.String(length=64), nullable=False),
        sa.Column("correlation_id", sa.Uuid(), nullable=False),
        sa.Column("attempt_count", sa.Integer(), server_default="1", nullable=False),
        sa.Column("input_tokens", sa.Integer(), server_default="0", nullable=False),
        sa.Column("output_tokens", sa.Integer(), server_default="0", nullable=False),
        sa.Column("total_tokens", sa.Integer(), server_default="0", nullable=False),
        sa.Column("cost_microusd", sa.BigInteger(), server_default="0", nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("released_at", sa.DateTime(timezone=True), nullable=True),
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
            "allowance_kind IN ('conversation_analysis', 'reply_generation', "
            "'first_message_generation', 'progress_insight')",
            name=op.f("ck_ai_usage_records_allowance_kind"),
        ),
        sa.CheckConstraint(
            "plan_code IN ('welcome', 'free', 'plus')",
            name=op.f("ck_ai_usage_records_plan_code"),
        ),
        sa.CheckConstraint(
            "status IN ('reserved', 'completed', 'released')",
            name=op.f("ck_ai_usage_records_status"),
        ),
        sa.CheckConstraint(
            "window_end > window_start", name=op.f("ck_ai_usage_records_window_order")
        ),
        sa.CheckConstraint(
            "attempt_count >= 1 AND attempt_count <= 3",
            name=op.f("ck_ai_usage_records_attempt_count"),
        ),
        sa.CheckConstraint(
            "input_tokens >= 0 AND output_tokens >= 0 AND total_tokens >= 0",
            name=op.f("ck_ai_usage_records_token_counts"),
        ),
        sa.CheckConstraint("cost_microusd >= 0", name=op.f("ck_ai_usage_records_cost_microusd")),
        sa.ForeignKeyConstraint(
            ["conversation_id"],
            ["conversations.id"],
            name=op.f("fk_ai_usage_records_conversation_id_conversations"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_ai_usage_records_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_ai_usage_records")),
        sa.UniqueConstraint(
            "user_id",
            "allowance_kind",
            "idempotency_key",
            name=op.f("uq_ai_usage_records_user_id"),
        ),
    )
    op.create_index("ix_ai_usage_status_created", "ai_usage_records", ["status", "created_at"])
    op.create_index(
        "ix_ai_usage_user_window",
        "ai_usage_records",
        ["user_id", "allowance_kind", "window_start"],
    )


def downgrade() -> None:
    """Remove usage and entitlement records without touching conversations."""
    op.drop_index("ix_ai_usage_user_window", table_name="ai_usage_records")
    op.drop_index("ix_ai_usage_status_created", table_name="ai_usage_records")
    op.drop_table("ai_usage_records")
    op.drop_index(
        "ix_subscription_entitlements_user_period",
        table_name="subscription_entitlements",
    )
    op.drop_table("subscription_entitlements")
