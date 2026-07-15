"""Conversation, participant, and message API contracts."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
ParticipantName = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)
]
MessageBody = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=10000)
]


class ConversationCreate(BaseModel):
    """Create an empty, user-owned conversation container."""

    title: Title
    other_participant_name: ParticipantName = "Other person"


class ConversationParticipantRead(BaseModel):
    """Conversation participant label."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    role: Literal["user", "other"]
    display_name: str
    position: int


class MessageCreate(BaseModel):
    """Create one manually entered message without import behavior."""

    participant_id: UUID
    body: MessageBody


class MessageRead(BaseModel):
    """Stored message contract."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    participant_id: UUID
    position: int
    speaker: Literal["user", "other"]
    body: str
    sent_at: datetime | None
    visible_timestamp_text: str | None
    timestamp_estimated: bool
    ocr_confidence: float | None
    source_screenshot_index: int | None
    status: Literal["extracted", "edited", "added", "confirmed"]
    created_at: datetime


class ImportSourceCreate(BaseModel):
    """Content-free metadata for an import source that has been disposed of."""

    source_type: Literal["screenshot", "paste"]
    source_index: int = Field(ge=0)
    mime_type: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
        | None
    ) = None
    byte_size: int | None = Field(default=None, ge=0, le=10_485_760)
    storage_status: Literal["deleted", "not_stored"]

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_storage_status(self) -> "ImportSourceCreate":
        expected = "deleted" if self.source_type == "screenshot" else "not_stored"
        if self.storage_status != expected:
            raise ValueError(f"{self.source_type} sources must be marked {expected}")
        return self


class NormalizedMessageCreate(BaseModel):
    """A reviewed message ready for normalized persistence."""

    speaker: Literal["user", "other"]
    text: MessageBody
    timestamp: datetime | None = None
    visible_timestamp_text: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)] | None
    ) = None
    timestamp_estimated: bool = False
    ocr_confidence: float | None = Field(default=None, ge=0, le=1)
    source_screenshot_index: int | None = Field(default=None, ge=0)
    review_status: Literal["extracted", "edited", "added"]

    model_config = ConfigDict(extra="forbid")


ExtractionVersion = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)
]


class ExtractionMetadata(BaseModel):
    """Provider provenance with no screenshot or transcript content."""

    model_config = ConfigDict(extra="forbid")

    provider: ExtractionVersion
    provider_version: ExtractionVersion
    extraction_version: ExtractionVersion
    preprocessing_version: ExtractionVersion
    confidence_available: bool


class ConversationConfirm(BaseModel):
    """User-confirmed, normalized import payload; no source content is accepted."""

    title: Title
    source_type: Literal["screenshot", "paste"]
    readiness_score: int = Field(ge=85, le=100)
    sources: list[ImportSourceCreate] = Field(min_length=1, max_length=10)
    messages: list[NormalizedMessageCreate] = Field(min_length=2, max_length=2000)
    extraction_metadata: ExtractionMetadata | None = None

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="after")
    def validate_source_references(self) -> "ConversationConfirm":
        source_indexes = [source.source_index for source in self.sources]
        if len(source_indexes) != len(set(source_indexes)):
            raise ValueError("source indexes must be unique")
        if any(source.source_type != self.source_type for source in self.sources):
            raise ValueError("source types must match the conversation source type")
        if self.source_type == "paste":
            if self.extraction_metadata is not None:
                raise ValueError("pasted conversations cannot include OCR extraction metadata")
            if any(message.source_screenshot_index is not None for message in self.messages):
                raise ValueError("pasted messages cannot reference screenshots")
        else:
            if self.extraction_metadata is None:
                raise ValueError("screenshot imports require extraction metadata")
            if any(
                message.source_screenshot_index not in source_indexes for message in self.messages
            ):
                raise ValueError("every screenshot message must reference a supplied source")
        if sum(source.byte_size or 0 for source in self.sources) > 52_428_800:
            raise ValueError("total source size cannot exceed 50 MB")

        speakers = {message.speaker for message in self.messages}
        if speakers != {"user", "other"}:
            raise ValueError("both speakers must be represented")
        normalized_texts = [message.text.casefold() for message in self.messages]
        if len(normalized_texts) != len(set(normalized_texts)):
            raise ValueError("duplicate messages must be resolved before confirmation")
        if any(
            message.ocr_confidence is not None
            and message.ocr_confidence < 0.8
            and message.review_status == "extracted"
            for message in self.messages
        ):
            raise ValueError("low-confidence messages must be reviewed before confirmation")
        if any(message.timestamp_estimated for message in self.messages):
            raise ValueError("estimated timestamps are not accepted")
        if self.source_type == "screenshot":
            message_source_indexes = [
                message.source_screenshot_index
                for message in self.messages
                if message.source_screenshot_index is not None
            ]
            if message_source_indexes != sorted(message_source_indexes):
                raise ValueError("screenshot messages must remain in source order")
        return self


class ConversationSourceRead(BaseModel):
    """Proof-oriented source metadata; screenshot paths and bytes are never returned."""

    model_config = ConfigDict(from_attributes=True)

    source_type: Literal["screenshot", "paste"]
    source_index: int
    mime_type: str | None
    byte_size: int | None
    storage_status: Literal["deleted", "not_stored"]
    deleted_at: datetime | None


class ConversationSummaryRead(BaseModel):
    """Conversation list item with no message body."""

    id: UUID
    title: str
    participant_name: str
    message_count: int
    source_type: Literal["manual", "screenshot", "paste"]
    status: Literal["draft", "confirmed"]
    readiness_score: int | None
    created_at: datetime
    updated_at: datetime


class ConversationDetailRead(BaseModel):
    """Owner-only conversation detail."""

    id: UUID
    title: str
    source_type: Literal["manual", "screenshot", "paste"]
    status: Literal["draft", "confirmed"]
    readiness_score: int | None
    confirmed_at: datetime | None
    participants: list[ConversationParticipantRead]
    messages: list[MessageRead]
    sources: list[ConversationSourceRead]
    extraction_metadata: ExtractionMetadata | None
    created_at: datetime
    updated_at: datetime
