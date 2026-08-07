"""Canonical conversation-event vocabulary and persistence inputs."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from uuid import UUID

type JsonScalar = str | int | float | bool | None
type JsonValue = JsonScalar | list[JsonValue] | dict[str, JsonValue]
type JsonObject = dict[str, JsonValue]


class ConversationEventType(StrEnum):
    """Closed Phase 6A.1 event vocabulary from the event specification."""

    TEXT_MESSAGE = "text_message"
    EMOJI_MESSAGE = "emoji_message"
    REACTION = "reaction"
    IMAGE = "image"
    VIDEO = "video"
    GIF = "gif"
    STICKER = "sticker"
    VOICE_NOTE = "voice_note"
    AUDIO = "audio"
    DOCUMENT = "document"
    LINK = "link"
    LOCATION = "location"
    CONTACT_CARD = "contact_card"
    POLL = "poll"
    PAYMENT_REQUEST = "payment_request"
    CALL_STARTED = "call_started"
    CALL_ENDED = "call_ended"
    MISSED_CALL = "missed_call"
    DECLINED_CALL = "declined_call"
    DELETED_MESSAGE = "deleted_message"
    EDITED_MESSAGE_MARKER = "edited_message_marker"
    REPLY_REFERENCE = "reply_reference"
    SYSTEM_MESSAGE = "system_message"
    DATE_SEPARATOR = "date_separator"
    UNREAD_SEPARATOR = "unread_separator"
    ENCRYPTION_NOTICE = "encryption_notice"
    MEMBER_EVENT = "member_event"
    UNKNOWN = "unknown"


class ConversationEventSpeaker(StrEnum):
    """Speaker attribution values, including explicit uncertainty."""

    USER = "user"
    OTHER = "other"
    SYSTEM = "system"
    UNKNOWN = "unknown"


class ConversationEventRelationshipType(StrEnum):
    """Closed relationship vocabulary from the event specification."""

    REACTION_TARGET = "reaction_target"
    REPLY_TARGET = "reply_target"
    EDIT_TARGET = "edit_target"
    MEDIA_CAPTION = "media_caption"
    CALL_PAIR = "call_pair"
    SYSTEM_CONTEXT = "system_context"
    DUPLICATE_OF = "duplicate_of"


PARTICIPANT_EVENT_TYPES = frozenset(
    {
        ConversationEventType.TEXT_MESSAGE,
        ConversationEventType.EMOJI_MESSAGE,
        ConversationEventType.IMAGE,
        ConversationEventType.VIDEO,
        ConversationEventType.GIF,
        ConversationEventType.STICKER,
        ConversationEventType.VOICE_NOTE,
        ConversationEventType.AUDIO,
        ConversationEventType.DOCUMENT,
        ConversationEventType.LINK,
        ConversationEventType.LOCATION,
        ConversationEventType.CONTACT_CARD,
        ConversationEventType.POLL,
        ConversationEventType.PAYMENT_REQUEST,
    }
)

SYSTEM_EVENT_TYPES = frozenset(
    {
        ConversationEventType.SYSTEM_MESSAGE,
        ConversationEventType.DATE_SEPARATOR,
        ConversationEventType.UNREAD_SEPARATOR,
        ConversationEventType.ENCRYPTION_NOTICE,
        ConversationEventType.MEMBER_EVENT,
    }
)


@dataclass(frozen=True, slots=True)
class ConfirmedConversationEvent:
    """One reviewed event ready for atomic owner-scoped persistence."""

    id: UUID
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
    deleted_at: datetime | None


@dataclass(frozen=True, slots=True)
class ConfirmedConversationEventRelationship:
    """One reviewed directed relationship between two event identifiers."""

    id: UUID
    source_event_id: UUID
    target_event_id: UUID
    relationship_type: ConversationEventRelationshipType
    confidence: float | None
    metadata: JsonObject


@dataclass(frozen=True, slots=True)
class ConfirmedConversationEventSequence:
    """Atomic replacement input for a confirmed event sequence."""

    schema_version: str
    events: tuple[ConfirmedConversationEvent, ...]
    relationships: tuple[ConfirmedConversationEventRelationship, ...]
