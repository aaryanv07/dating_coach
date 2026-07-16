"""Versioned API contracts for typed conversation events."""

import json
from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.domain.conversation_events import (
    SYSTEM_EVENT_TYPES,
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
    JsonObject,
    JsonValue,
)

EventText = Annotated[str, StringConstraints(max_length=10000)]
RawTimestamp = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
SourceRegionId = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)
]
Confidence = Annotated[float, Field(ge=0, le=1)]

_FORBIDDEN_METADATA_KEYS = frozenset(
    {
        "account_number",
        "absolute_path",
        "contact_number",
        "file_bytes",
        "image_bytes",
        "phone_number",
        "raw_prompt",
        "screenshot_bytes",
        "screenshot_path",
        "source_path",
        "upi_id",
    }
)


def _metadata_depth(value: JsonValue, *, current: int = 0) -> int:
    if isinstance(value, dict):
        return max(
            [current, *(_metadata_depth(item, current=current + 1) for item in value.values())]
        )
    if isinstance(value, list):
        return max([current, *(_metadata_depth(item, current=current + 1) for item in value)])
    return current


def _validate_metadata(metadata: JsonObject) -> JsonObject:
    """Bound metadata and reject common raw-source or direct-identifier fields."""
    keys: set[str] = set()

    def collect(value: JsonValue) -> None:
        if isinstance(value, dict):
            for key, item in value.items():
                keys.add(key.casefold())
                collect(item)
        elif isinstance(value, list):
            for item in value:
                collect(item)

    collect(metadata)
    rejected = keys & _FORBIDDEN_METADATA_KEYS
    if rejected:
        raise ValueError(f"metadata contains prohibited fields: {', '.join(sorted(rejected))}")
    if _metadata_depth(metadata) > 4:
        raise ValueError("metadata nesting cannot exceed four levels")
    if len(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")).encode()) > 16_384:
        raise ValueError("metadata cannot exceed 16 KB")
    return metadata


class ConversationEventWrite(BaseModel):
    """One event in a client-confirmed ordered sequence."""

    model_config = ConfigDict(extra="forbid")

    id: UUID
    position: int = Field(ge=0, le=5000)
    event_type: ConversationEventType
    speaker: ConversationEventSpeaker
    text: EventText | None = None
    timestamp: datetime | None = None
    timestamp_is_estimated: bool = False
    raw_timestamp_text: RawTimestamp | None = None
    source_image_index: int | None = Field(default=None, ge=0, le=1000)
    source_region_id: SourceRegionId | None = None
    ocr_confidence: Confidence | None = None
    classification_confidence: Confidence | None = None
    speaker_confidence: Confidence | None = None
    timestamp_confidence: Confidence | None = None
    relationship_confidence: Confidence | None = None
    requires_review: bool = False
    metadata: JsonObject = Field(default_factory=dict)
    deleted_at: datetime | None = None

    @model_validator(mode="after")
    def validate_event(self) -> "ConversationEventWrite":
        self.metadata = _validate_metadata(self.metadata)
        if (
            self.event_type in SYSTEM_EVENT_TYPES
            and self.speaker != ConversationEventSpeaker.SYSTEM
        ):
            raise ValueError("structural and system events must use the system speaker")
        if self.event_type == ConversationEventType.UNKNOWN and not self.requires_review:
            raise ValueError("unknown events must require review")
        if self.event_type in {
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventType.EMOJI_MESSAGE,
        } and not (self.text and self.text.strip()):
            raise ValueError("text and emoji messages require visible text")
        if self.timestamp_is_estimated and (
            self.timestamp is None or self.raw_timestamp_text is None
        ):
            raise ValueError("estimated timestamps require a timestamp and its visible source text")
        return self


class ConversationEventRelationshipWrite(BaseModel):
    """One directed relationship between event identifiers in the same payload."""

    model_config = ConfigDict(extra="forbid")

    id: UUID
    source_event_id: UUID
    target_event_id: UUID
    relationship_type: ConversationEventRelationshipType
    confidence: Confidence | None = None
    metadata: JsonObject = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_relationship(self) -> "ConversationEventRelationshipWrite":
        self.metadata = _validate_metadata(self.metadata)
        if self.source_event_id == self.target_event_id:
            raise ValueError("an event cannot target itself")
        return self


class ConversationEventSequenceReplace(BaseModel):
    """Atomic v1 event replacement; legacy messages are deliberately untouched."""

    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["conversation-events.v1"]
    events: list[ConversationEventWrite] = Field(min_length=1, max_length=5000)
    relationships: list[ConversationEventRelationshipWrite] = Field(
        default_factory=list, max_length=10000
    )

    @model_validator(mode="after")
    def validate_sequence(self) -> "ConversationEventSequenceReplace":
        event_ids = [event.id for event in self.events]
        positions = [event.position for event in self.events]
        if len(event_ids) != len(set(event_ids)):
            raise ValueError("event ids must be unique")
        if len(positions) != len(set(positions)):
            raise ValueError("event positions must be unique")
        if positions != list(range(len(positions))):
            raise ValueError("event positions must be contiguous and ordered from zero")

        events_by_id = {event.id: event for event in self.events}
        relationship_ids = [relationship.id for relationship in self.relationships]
        if len(relationship_ids) != len(set(relationship_ids)):
            raise ValueError("relationship ids must be unique")
        keys = [
            (
                relationship.source_event_id,
                relationship.target_event_id,
                relationship.relationship_type,
            )
            for relationship in self.relationships
        ]
        if len(keys) != len(set(keys)):
            raise ValueError("event relationships must be unique")
        if any(
            relationship.source_event_id not in events_by_id
            or relationship.target_event_id not in events_by_id
            for relationship in self.relationships
        ):
            raise ValueError("relationships must reference events in this sequence")

        expected_source_types = {
            ConversationEventRelationshipType.REACTION_TARGET: ConversationEventType.REACTION,
            ConversationEventRelationshipType.REPLY_TARGET: ConversationEventType.REPLY_REFERENCE,
            ConversationEventRelationshipType.EDIT_TARGET: (
                ConversationEventType.EDITED_MESSAGE_MARKER
            ),
        }
        for relationship in self.relationships:
            source = events_by_id[relationship.source_event_id]
            expected_source = expected_source_types.get(relationship.relationship_type)
            if expected_source is not None and source.event_type != expected_source:
                raise ValueError("relationship type does not match its source event type")
            if relationship.confidence is None or source.relationship_confidence is None:
                raise ValueError("asserted relationships require explicit confidence")

        reaction_targets = {
            relationship.source_event_id
            for relationship in self.relationships
            if relationship.relationship_type == ConversationEventRelationshipType.REACTION_TARGET
        }
        for event in self.events:
            if (
                event.event_type == ConversationEventType.REACTION
                and event.id not in reaction_targets
                and not event.requires_review
            ):
                raise ValueError("a resolved reaction must reference its target event")
        return self


class ConversationEventRead(BaseModel):
    """Stored or compatibility-projected event contract."""

    id: UUID
    conversation_id: UUID
    position: int
    event_type: ConversationEventType
    speaker: ConversationEventSpeaker
    text: str | None
    timestamp: datetime | None
    timestamp_is_estimated: bool
    raw_timestamp_text: str | None
    source_image_index: int | None
    source_region_id: str | None
    ocr_confidence: float | None
    classification_confidence: float | None
    speaker_confidence: float | None
    timestamp_confidence: float | None
    relationship_confidence: float | None
    requires_review: bool
    metadata: JsonObject
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None


class ConversationEventRelationshipRead(BaseModel):
    """Stored relationship contract."""

    id: UUID
    source_event_id: UUID
    target_event_id: UUID
    relationship_type: ConversationEventRelationshipType
    confidence: float | None
    metadata: JsonObject
    created_at: datetime
    updated_at: datetime


class ConversationEventSequenceRead(BaseModel):
    """Event view with an explicit persisted-versus-projected compatibility mode."""

    schema_version: Literal["conversation-events.v1"] = "conversation-events.v1"
    compatibility_mode: Literal["persisted_events", "message_projection"]
    events: list[ConversationEventRead]
    relationships: list[ConversationEventRelationshipRead]
