"""Add confirmed conversation import persistence.

Revision ID: 20260714_0002
Revises: 20260714_0001
Create Date: 2026-07-14
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260714_0002"
down_revision: str | None = "20260714_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Store normalized imports while retaining no screenshot content."""
    op.add_column(
        "conversations",
        sa.Column("source_type", sa.String(length=16), server_default="manual", nullable=False),
    )
    op.add_column(
        "conversations",
        sa.Column("status", sa.String(length=16), server_default="draft", nullable=False),
    )
    op.add_column("conversations", sa.Column("readiness_score", sa.Integer(), nullable=True))
    op.add_column(
        "conversations", sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True)
    )
    op.create_check_constraint(
        op.f("ck_conversations_source_type"),
        "conversations",
        "source_type IN ('manual', 'screenshot', 'paste')",
    )
    op.create_check_constraint(
        op.f("ck_conversations_status"),
        "conversations",
        "status IN ('draft', 'confirmed')",
    )
    op.create_check_constraint(
        op.f("ck_conversations_readiness_score"),
        "conversations",
        "readiness_score IS NULL OR (readiness_score >= 0 AND readiness_score <= 100)",
    )

    op.add_column("messages", sa.Column("speaker", sa.String(length=16), nullable=True))
    op.execute(
        """
        UPDATE messages
        SET speaker = conversation_participants.role
        FROM conversation_participants
        WHERE messages.participant_id = conversation_participants.id
        """
    )
    op.alter_column("messages", "speaker", nullable=False)
    op.add_column(
        "messages",
        sa.Column("timestamp_estimated", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.add_column("messages", sa.Column("ocr_confidence", sa.Float(), nullable=True))
    op.add_column("messages", sa.Column("source_screenshot_index", sa.Integer(), nullable=True))
    op.add_column(
        "messages",
        sa.Column("status", sa.String(length=16), server_default="added", nullable=False),
    )
    op.create_check_constraint(
        op.f("ck_messages_speaker"), "messages", "speaker IN ('user', 'other')"
    )
    op.create_check_constraint(
        op.f("ck_messages_ocr_confidence"),
        "messages",
        "ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 1)",
    )
    op.create_check_constraint(
        op.f("ck_messages_source_screenshot_index"),
        "messages",
        "source_screenshot_index IS NULL OR source_screenshot_index >= 0",
    )
    op.create_check_constraint(
        op.f("ck_messages_status"),
        "messages",
        "status IN ('extracted', 'edited', 'added', 'confirmed')",
    )

    op.create_table(
        "conversation_sources",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("conversation_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=16), nullable=False),
        sa.Column("source_index", sa.Integer(), nullable=False),
        sa.Column("mime_type", sa.String(length=120), nullable=True),
        sa.Column("byte_size", sa.Integer(), nullable=True),
        sa.Column("storage_status", sa.String(length=16), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "source_type IN ('screenshot', 'paste')",
            name=op.f("ck_conversation_sources_source_type"),
        ),
        sa.CheckConstraint(
            "storage_status IN ('deleted', 'not_stored')",
            name=op.f("ck_conversation_sources_storage_status"),
        ),
        sa.CheckConstraint("source_index >= 0", name=op.f("ck_conversation_sources_source_index")),
        sa.CheckConstraint(
            "byte_size IS NULL OR byte_size >= 0",
            name=op.f("ck_conversation_sources_byte_size"),
        ),
        sa.CheckConstraint(
            "(storage_status = 'deleted' AND deleted_at IS NOT NULL) OR "
            "(storage_status = 'not_stored' AND deleted_at IS NULL)",
            name=op.f("ck_conversation_sources_disposal_state"),
        ),
        sa.ForeignKeyConstraint(
            ["conversation_id"],
            ["conversations.id"],
            name=op.f("fk_conversation_sources_conversation_id_conversations"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_conversation_sources")),
        sa.UniqueConstraint(
            "conversation_id",
            "source_index",
            name=op.f("uq_conversation_sources_conversation_id"),
        ),
    )


def downgrade() -> None:
    """Remove Phase 4 import metadata and restore the Phase 3 schema."""
    op.drop_table("conversation_sources")

    op.drop_constraint(op.f("ck_messages_status"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_source_screenshot_index"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_ocr_confidence"), "messages", type_="check")
    op.drop_constraint(op.f("ck_messages_speaker"), "messages", type_="check")
    op.drop_column("messages", "status")
    op.drop_column("messages", "source_screenshot_index")
    op.drop_column("messages", "ocr_confidence")
    op.drop_column("messages", "timestamp_estimated")
    op.drop_column("messages", "speaker")

    op.drop_constraint(op.f("ck_conversations_readiness_score"), "conversations", type_="check")
    op.drop_constraint(op.f("ck_conversations_status"), "conversations", type_="check")
    op.drop_constraint(op.f("ck_conversations_source_type"), "conversations", type_="check")
    op.drop_column("conversations", "confirmed_at")
    op.drop_column("conversations", "readiness_score")
    op.drop_column("conversations", "status")
    op.drop_column("conversations", "source_type")
