"""Phase 3 identity, consent, and conversation persistence models."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Literal
from uuid import UUID, uuid4

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.domain.conversation_events import JsonObject

DeletionStatus = Literal["pending", "completed", "failed"]


def utc_now() -> datetime:
    """Return an aware UTC timestamp for Python-side defaults."""
    return datetime.now(UTC)


class TimestampMixin:
    """Created and updated timestamps shared by mutable records."""

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False
    )


class User(TimestampMixin, Base):
    """Server-owned application user linked to a verified auth subject."""

    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    auth_subject: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    preferences: Mapped[UserPreference | None] = relationship(
        back_populates="user", cascade="all, delete-orphan", uselist=False
    )
    communication_profile: Mapped[CommunicationProfile | None] = relationship(
        back_populates="user", cascade="all, delete-orphan", uselist=False
    )
    consent_records: Mapped[list[ConsentRecord]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    conversations: Mapped[list[Conversation]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )


class UserPreference(TimestampMixin, Base):
    """User-controlled application preferences."""

    __tablename__ = "user_preferences"
    __table_args__ = (
        CheckConstraint(
            "coaching_style IN ('gentle', 'balanced', 'direct')",
            name="coaching_style",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    preferred_language: Mapped[str] = mapped_column(String(32), default="english")
    coaching_style: Mapped[str] = mapped_column(String(16), default="balanced")
    save_history: Mapped[bool] = mapped_column(Boolean, default=False)

    user: Mapped[User] = relationship(back_populates="preferences")


class CommunicationProfile(TimestampMixin, Base):
    """Explicit communication choices; never inferred personality claims."""

    __tablename__ = "communication_profiles"

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    preferred_name: Mapped[str | None] = mapped_column(String(80), nullable=True)
    relationship_intention: Mapped[str | None] = mapped_column(String(32), nullable=True)
    communication_tone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    texting_style: Mapped[str | None] = mapped_column(String(32), nullable=True)
    preferred_message_length: Mapped[str | None] = mapped_column(String(16), nullable=True)
    uses_emojis: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    user: Mapped[User] = relationship(back_populates="communication_profile")


class ConsentRecord(Base):
    """Append-only record of a user's explicit consent decision."""

    __tablename__ = "consent_records"
    __table_args__ = (Index("ix_consent_records_user_type", "user_id", "consent_type"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    consent_type: Mapped[str] = mapped_column(String(64), nullable=False)
    granted: Mapped[bool] = mapped_column(Boolean, nullable=False)
    policy_version: Mapped[str] = mapped_column(String(32), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )

    user: Mapped[User] = relationship(back_populates="consent_records")


class Conversation(TimestampMixin, Base):
    """A private conversation owned by exactly one application user."""

    __tablename__ = "conversations"
    __table_args__ = (
        Index("ix_conversations_owner_updated", "owner_id", "updated_at"),
        CheckConstraint("source_type IN ('manual', 'screenshot', 'paste')", name="source_type"),
        CheckConstraint("status IN ('draft', 'confirmed')", name="status"),
        CheckConstraint(
            "readiness_score IS NULL OR (readiness_score >= 0 AND readiness_score <= 100)",
            name="readiness_score",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    source_type: Mapped[str] = mapped_column(String(16), default="manual", nullable=False)
    status: Mapped[str] = mapped_column(String(16), default="draft", nullable=False)
    readiness_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    extraction_metadata: Mapped[dict[str, str | bool] | None] = mapped_column(JSON, nullable=True)

    owner: Mapped[User] = relationship(back_populates="conversations")
    participants: Mapped[list[ConversationParticipant]] = relationship(
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ConversationParticipant.position",
    )
    messages: Mapped[list[Message]] = relationship(
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="Message.position",
    )
    events: Mapped[list[ConversationEvent]] = relationship(
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ConversationEvent.position",
    )
    sources: Mapped[list[ConversationSource]] = relationship(
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ConversationSource.source_index",
    )


class ConversationParticipant(Base):
    """A user-controlled participant label inside a conversation."""

    __tablename__ = "conversation_participants"
    __table_args__ = (
        UniqueConstraint("conversation_id", "position"),
        CheckConstraint("role IN ('user', 'other')", name="role"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    display_name: Mapped[str] = mapped_column(String(80), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)

    conversation: Mapped[Conversation] = relationship(back_populates="participants")
    messages: Mapped[list[Message]] = relationship(back_populates="participant")


class ConversationSource(Base):
    """Metadata proving that temporary source content was not retained."""

    __tablename__ = "conversation_sources"
    __table_args__ = (
        UniqueConstraint("conversation_id", "source_index"),
        CheckConstraint("source_type IN ('screenshot', 'paste')", name="source_type"),
        CheckConstraint("storage_status IN ('deleted', 'not_stored')", name="storage_status"),
        CheckConstraint("source_index >= 0", name="source_index"),
        CheckConstraint("byte_size IS NULL OR byte_size >= 0", name="byte_size"),
        CheckConstraint(
            "(storage_status = 'deleted' AND deleted_at IS NOT NULL) OR "
            "(storage_status = 'not_stored' AND deleted_at IS NULL)",
            name="disposal_state",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
    )
    source_type: Mapped[str] = mapped_column(String(16), nullable=False)
    source_index: Mapped[int] = mapped_column(Integer, nullable=False)
    mime_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    byte_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    storage_status: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    conversation: Mapped[Conversation] = relationship(back_populates="sources")


class Message(TimestampMixin, Base):
    """A manually created Phase 3 message record."""

    __tablename__ = "messages"
    __table_args__ = (
        UniqueConstraint("conversation_id", "position"),
        Index("ix_messages_conversation_created", "conversation_id", "created_at"),
        CheckConstraint("speaker IN ('user', 'other')", name="speaker"),
        CheckConstraint(
            "ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 1)",
            name="ocr_confidence",
        ),
        CheckConstraint(
            "source_screenshot_index IS NULL OR source_screenshot_index >= 0",
            name="source_screenshot_index",
        ),
        CheckConstraint("status IN ('extracted', 'edited', 'added', 'confirmed')", name="status"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
    )
    participant_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversation_participants.id", ondelete="CASCADE"),
        nullable=False,
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    speaker: Mapped[str] = mapped_column(String(16), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    visible_timestamp_text: Mapped[str | None] = mapped_column(String(80), nullable=True)
    timestamp_estimated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    ocr_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    source_screenshot_index: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="added", nullable=False)

    conversation: Mapped[Conversation] = relationship(back_populates="messages")
    participant: Mapped[ConversationParticipant] = relationship(back_populates="messages")


class ConversationEvent(TimestampMixin, Base):
    """A typed, reviewed conversation item that does not assume every item is a message."""

    __tablename__ = "conversation_events"
    __table_args__ = (
        UniqueConstraint("conversation_id", "position"),
        Index("ix_conversation_events_conversation_created", "conversation_id", "created_at"),
        Index("ix_conversation_events_conversation_type", "conversation_id", "event_type"),
        CheckConstraint("position >= 0", name="position"),
        CheckConstraint(
            "event_type IN ('text_message', 'emoji_message', 'reaction', 'image', 'video', "
            "'gif', 'sticker', 'voice_note', 'audio', 'document', 'link', 'location', "
            "'contact_card', 'poll', 'payment_request', 'call_started', 'call_ended', "
            "'missed_call', 'declined_call', 'deleted_message', 'edited_message_marker', "
            "'reply_reference', 'system_message', 'date_separator', 'unread_separator', "
            "'encryption_notice', 'member_event', 'unknown')",
            name="event_type",
        ),
        CheckConstraint("speaker IN ('user', 'other', 'system', 'unknown')", name="speaker"),
        CheckConstraint(
            "source_image_index IS NULL OR source_image_index >= 0",
            name="source_image_index",
        ),
        CheckConstraint(
            "ocr_confidence IS NULL OR (ocr_confidence >= 0 AND ocr_confidence <= 1)",
            name="ocr_confidence",
        ),
        CheckConstraint(
            "classification_confidence IS NULL OR "
            "(classification_confidence >= 0 AND classification_confidence <= 1)",
            name="classification_confidence",
        ),
        CheckConstraint(
            "speaker_confidence IS NULL OR (speaker_confidence >= 0 AND speaker_confidence <= 1)",
            name="speaker_confidence",
        ),
        CheckConstraint(
            "timestamp_confidence IS NULL OR "
            "(timestamp_confidence >= 0 AND timestamp_confidence <= 1)",
            name="timestamp_confidence",
        ),
        CheckConstraint(
            "relationship_confidence IS NULL OR "
            "(relationship_confidence >= 0 AND relationship_confidence <= 1)",
            name="relationship_confidence",
        ),
        CheckConstraint(
            "event_type NOT IN ('system_message', 'date_separator', 'unread_separator', "
            "'encryption_notice', 'member_event') OR speaker = 'system'",
            name="system_speaker",
        ),
        CheckConstraint(
            "event_type != 'unknown' OR requires_review",
            name="unknown_requires_review",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    conversation_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    event_type: Mapped[str] = mapped_column(String(32), nullable=False)
    speaker: Mapped[str] = mapped_column(String(16), nullable=False)
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    timestamp: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    timestamp_is_estimated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    raw_timestamp_text: Mapped[str | None] = mapped_column(String(80), nullable=True)
    source_image_index: Mapped[int | None] = mapped_column(Integer, nullable=True)
    source_region_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    ocr_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    classification_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    speaker_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    timestamp_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    relationship_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    requires_review: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    metadata_json: Mapped[JsonObject] = mapped_column(JSON, default=dict, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    conversation: Mapped[Conversation] = relationship(back_populates="events")
    outgoing_relationships: Mapped[list[ConversationEventRelationship]] = relationship(
        back_populates="source_event",
        cascade="all, delete-orphan",
        foreign_keys="ConversationEventRelationship.source_event_id",
    )
    incoming_relationships: Mapped[list[ConversationEventRelationship]] = relationship(
        back_populates="target_event",
        cascade="all, delete-orphan",
        foreign_keys="ConversationEventRelationship.target_event_id",
    )


class ConversationEventRelationship(TimestampMixin, Base):
    """A directed, typed relationship between two events in the same conversation."""

    __tablename__ = "conversation_event_relationships"
    __table_args__ = (
        UniqueConstraint("source_event_id", "target_event_id", "relationship_type"),
        Index("ix_event_relationships_source", "source_event_id"),
        Index("ix_event_relationships_target", "target_event_id"),
        CheckConstraint("source_event_id != target_event_id", name="distinct_events"),
        CheckConstraint(
            "relationship_type IN ('reaction_target', 'reply_target', 'edit_target', "
            "'media_caption', 'call_pair', 'system_context', 'duplicate_of')",
            name="relationship_type",
        ),
        CheckConstraint(
            "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
            name="confidence",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    source_event_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversation_events.id", ondelete="CASCADE"),
        nullable=False,
    )
    target_event_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("conversation_events.id", ondelete="CASCADE"),
        nullable=False,
    )
    relationship_type: Mapped[str] = mapped_column(String(32), nullable=False)
    confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    metadata_json: Mapped[JsonObject] = mapped_column(JSON, default=dict, nullable=False)

    source_event: Mapped[ConversationEvent] = relationship(
        back_populates="outgoing_relationships", foreign_keys=[source_event_id]
    )
    target_event: Mapped[ConversationEvent] = relationship(
        back_populates="incoming_relationships", foreign_keys=[target_event_id]
    )


class DeletionRequest(Base):
    """Idempotent account-deletion request and provider-cleanup checkpoint."""

    __tablename__ = "deletion_requests"
    __table_args__ = (
        CheckConstraint("status IN ('pending', 'completed', 'failed')", name="status"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    status: Mapped[DeletionStatus] = mapped_column(String(16), default="pending", nullable=False)
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, nullable=False
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
