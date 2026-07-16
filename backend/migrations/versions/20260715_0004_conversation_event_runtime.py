"""Add the reversible conversation-event runtime foundation.

Revision ID: 20260715_0004
Revises: 20260714_0003
Create Date: 2026-07-15
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "20260715_0004"
down_revision: str | None = "20260714_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add events beside messages without rewriting existing message rows."""
    op.create_table(
        "conversation_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("conversation_id", sa.Uuid(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(length=32), nullable=False),
        sa.Column("speaker", sa.String(length=16), nullable=False),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "timestamp_is_estimated", sa.Boolean(), server_default=sa.false(), nullable=False
        ),
        sa.Column("raw_timestamp_text", sa.String(length=80), nullable=True),
        sa.Column("source_image_index", sa.Integer(), nullable=True),
        sa.Column("source_region_id", sa.String(length=120), nullable=True),
        sa.Column("ocr_confidence", sa.Float(), nullable=True),
        sa.Column("classification_confidence", sa.Float(), nullable=True),
        sa.Column("speaker_confidence", sa.Float(), nullable=True),
        sa.Column("timestamp_confidence", sa.Float(), nullable=True),
        sa.Column("relationship_confidence", sa.Float(), nullable=True),
        sa.Column("requires_review", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
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
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("position >= 0", name=op.f("ck_conversation_events_position")),
        sa.CheckConstraint(
            "event_type IN ('text_message', 'emoji_message', 'reaction', 'image', 'video', "
            "'gif', 'sticker', 'voice_note', 'audio', 'document', 'link', 'location', "
            "'contact_card', 'poll', 'payment_request', 'call_started', 'call_ended', "
            "'missed_call', 'declined_call', 'deleted_message', 'edited_message_marker', "
            "'reply_reference', 'system_message', 'date_separator', 'unread_separator', "
            "'encryption_notice', 'member_event', 'unknown')",
            name=op.f("ck_conversation_events_event_type"),
        ),
        sa.CheckConstraint(
            "speaker IN ('user', 'other', 'system', 'unknown')",
            name=op.f("ck_conversation_events_speaker"),
        ),
        sa.CheckConstraint(
            "source_image_index IS NULL OR source_image_index >= 0",
            name=op.f("ck_conversation_events_source_image_index"),
        ),
        sa.CheckConstraint(
            "ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 1)",
            name=op.f("ck_conversation_events_ocr_confidence"),
        ),
        sa.CheckConstraint(
            "classification_confidence IS NULL OR "
            "(classification_confidence >= 0 AND classification_confidence <= 1)",
            name=op.f("ck_conversation_events_classification_confidence"),
        ),
        sa.CheckConstraint(
            "speaker_confidence IS NULL OR (speaker_confidence >= 0 AND speaker_confidence <= 1)",
            name=op.f("ck_conversation_events_speaker_confidence"),
        ),
        sa.CheckConstraint(
            "timestamp_confidence IS NULL OR "
            "(timestamp_confidence >= 0 AND timestamp_confidence <= 1)",
            name=op.f("ck_conversation_events_timestamp_confidence"),
        ),
        sa.CheckConstraint(
            "relationship_confidence IS NULL OR "
            "(relationship_confidence >= 0 AND relationship_confidence <= 1)",
            name=op.f("ck_conversation_events_relationship_confidence"),
        ),
        sa.CheckConstraint(
            "event_type NOT IN ('system_message', 'date_separator', 'unread_separator', "
            "'encryption_notice', 'member_event') OR speaker = 'system'",
            name=op.f("ck_conversation_events_system_speaker"),
        ),
        sa.CheckConstraint(
            "event_type != 'unknown' OR requires_review",
            name=op.f("ck_conversation_events_unknown_requires_review"),
        ),
        sa.ForeignKeyConstraint(
            ["conversation_id"],
            ["conversations.id"],
            name=op.f("fk_conversation_events_conversation_id_conversations"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_conversation_events")),
        sa.UniqueConstraint(
            "conversation_id",
            "position",
            name=op.f("uq_conversation_events_conversation_id"),
        ),
    )
    op.create_index(
        "ix_conversation_events_conversation_created",
        "conversation_events",
        ["conversation_id", "created_at"],
    )
    op.create_index(
        "ix_conversation_events_conversation_type",
        "conversation_events",
        ["conversation_id", "event_type"],
    )

    op.create_table(
        "conversation_event_relationships",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("source_event_id", sa.Uuid(), nullable=False),
        sa.Column("target_event_id", sa.Uuid(), nullable=False),
        sa.Column("relationship_type", sa.String(length=32), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
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
            "source_event_id != target_event_id",
            name=op.f("ck_conversation_event_relationships_distinct_events"),
        ),
        sa.CheckConstraint(
            "relationship_type IN ('reaction_target', 'reply_target', 'edit_target', "
            "'media_caption', 'call_pair', 'system_context', 'duplicate_of')",
            name=op.f("ck_conversation_event_relationships_relationship_type"),
        ),
        sa.CheckConstraint(
            "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
            name=op.f("ck_conversation_event_relationships_confidence"),
        ),
        sa.ForeignKeyConstraint(
            ["source_event_id"],
            ["conversation_events.id"],
            name=op.f("fk_conversation_event_relationships_source_event_id_conversation_events"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["target_event_id"],
            ["conversation_events.id"],
            name=op.f("fk_conversation_event_relationships_target_event_id_conversation_events"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_conversation_event_relationships")),
        sa.UniqueConstraint(
            "source_event_id",
            "target_event_id",
            "relationship_type",
            name=op.f("uq_conversation_event_relationships_source_event_id"),
        ),
    )
    op.create_index(
        "ix_event_relationships_source",
        "conversation_event_relationships",
        ["source_event_id"],
    )
    op.create_index(
        "ix_event_relationships_target",
        "conversation_event_relationships",
        ["target_event_id"],
    )


def downgrade() -> None:
    """Remove only event-runtime tables; legacy messages remain unchanged."""
    op.drop_index("ix_event_relationships_target", table_name="conversation_event_relationships")
    op.drop_index("ix_event_relationships_source", table_name="conversation_event_relationships")
    op.drop_table("conversation_event_relationships")
    op.drop_index("ix_conversation_events_conversation_type", table_name="conversation_events")
    op.drop_index("ix_conversation_events_conversation_created", table_name="conversation_events")
    op.drop_table("conversation_events")
