"""Normalized, user-confirmed conversation import inputs."""

from dataclasses import dataclass
from datetime import datetime
from typing import Literal

ImportSourceType = Literal["screenshot", "paste"]
ImportStorageStatus = Literal["deleted", "not_stored"]
MessageSpeaker = Literal["user", "other"]


@dataclass(frozen=True, slots=True)
class ConfirmedExtractionMetadata:
    """Content-free provenance for the reviewed on-device extraction."""

    provider: str
    provider_version: str
    extraction_version: str
    preprocessing_version: str
    confidence_available: bool


@dataclass(frozen=True, slots=True)
class ConfirmedSource:
    """Non-content metadata for a temporary import source."""

    source_type: ImportSourceType
    source_index: int
    mime_type: str | None
    byte_size: int | None
    storage_status: ImportStorageStatus


@dataclass(frozen=True, slots=True)
class ConfirmedMessage:
    """One normalized message after the user has reviewed it."""

    speaker: MessageSpeaker
    text: str
    timestamp: datetime | None
    visible_timestamp_text: str | None
    timestamp_estimated: bool
    ocr_confidence: float | None
    source_screenshot_index: int | None


@dataclass(frozen=True, slots=True)
class ConfirmedConversation:
    """Atomic persistence input for a completed review session."""

    title: str
    source_type: ImportSourceType
    readiness_score: int
    sources: tuple[ConfirmedSource, ...]
    messages: tuple[ConfirmedMessage, ...]
    extraction_metadata: ConfirmedExtractionMetadata | None
