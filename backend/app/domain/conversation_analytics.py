"""Immutable versioned contracts for deterministic conversation analytics."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from uuid import UUID

from app.domain.conversation_events import (
    ConfirmedConversationEventSequence,
    ConversationEventSpeaker,
    ConversationEventType,
)

ANALYTICS_INPUT_SCHEMA_VERSION = "conversation-analytics-input.v1"
ANALYTICS_SCHEMA_VERSION = "conversation-analytics.v1"
ANALYTICS_CALCULATION_VERSION = "deterministic-conversation-analytics.v1"

type AnalyticsInputSchemaVersion = Literal["conversation-analytics-input.v1"]
type AnalyticsSchemaVersion = Literal["conversation-analytics.v1"]
type AnalyticsCalculationVersion = Literal["deterministic-conversation-analytics.v1"]
type SourceEventSchemaVersion = Literal["conversation-events.v1"]


class AnalyticsReviewStatus(StrEnum):
    """Whether the supplied canonical timeline is confirmed for analysis."""

    CONFIRMED = "confirmed"
    INCOMPLETE_REVIEW = "incomplete_review"


class DeterministicConfidence(StrEnum):
    """Evidence sufficiency, never an AI or relationship-confidence claim."""

    COMPLETE = "complete"
    REDUCED = "reduced"
    UNAVAILABLE = "unavailable"


class MissingDataReason(StrEnum):
    """Stable reasons that reduce or prevent deterministic calculation."""

    INCOMPLETE_REVIEW = "incomplete_review"
    MISSING_TIMESTAMP = "missing_timestamp"
    ESTIMATED_TIMESTAMP = "estimated_timestamp"
    MISSING_PARTICIPANT = "missing_participant"
    UNKNOWN_EVENT = "unknown_event"
    UNRESOLVED_RELATIONSHIP = "unresolved_relationship"
    INCOMPLETE_TIMELINE = "incomplete_timeline"
    PARTIAL_CONVERSATION = "partial_conversation"
    INSUFFICIENT_EVIDENCE = "insufficient_evidence"


class MetricUnit(StrEnum):
    """Machine-readable units used by internal analytics values."""

    COUNT = "count"
    PERCENT = "percent"
    SECONDS = "seconds"
    EVENT_ID = "event_id"
    REACTION_TYPE_COUNTS = "reaction_type_counts"


@dataclass(frozen=True, slots=True)
class TimelineGapV1:
    """A reviewed declaration that the imported timeline is incomplete."""

    before_event_id: UUID | None = None
    after_event_id: UUID | None = None
    schema_version: Literal["analytics-timeline-gap.v1"] = "analytics-timeline-gap.v1"

    def __post_init__(self) -> None:
        if self.before_event_id is None and self.after_event_id is None:
            raise ValueError("a timeline gap must reference at least one boundary event")


@dataclass(frozen=True, slots=True)
class AnalyticsInputV1:
    """Confirmed canonical input plus explicit conversation-level quality facts."""

    event_sequence: ConfirmedConversationEventSequence
    review_status: AnalyticsReviewStatus = AnalyticsReviewStatus.CONFIRMED
    timeline_gaps: tuple[TimelineGapV1, ...] = ()
    is_partial: bool = False
    schema_version: AnalyticsInputSchemaVersion = "conversation-analytics-input.v1"

    def __post_init__(self) -> None:
        if self.schema_version != ANALYTICS_INPUT_SCHEMA_VERSION:
            raise ValueError("unsupported analytics input schema version")
        if self.event_sequence.schema_version != "conversation-events.v1":
            raise ValueError("unsupported conversation-event schema version")
        event_ids = {event.id for event in self.event_sequence.events}
        if any(
            boundary is not None and boundary not in event_ids
            for gap in self.timeline_gaps
            for boundary in (gap.before_event_id, gap.after_event_id)
        ):
            raise ValueError("timeline gaps must reference events in the canonical sequence")


@dataclass(frozen=True, slots=True)
class EvidenceReferenceV1:
    """Content-free structural evidence for one deterministic calculation."""

    event_ids: tuple[UUID, ...] = ()
    relationship_ids: tuple[UUID, ...] = ()
    calculation_version: AnalyticsCalculationVersion = "deterministic-conversation-analytics.v1"
    schema_version: Literal["analytics-evidence-reference.v1"] = "analytics-evidence-reference.v1"

    def __post_init__(self) -> None:
        if self.calculation_version != ANALYTICS_CALCULATION_VERSION:
            raise ValueError("unsupported analytics calculation version")


@dataclass(frozen=True, slots=True)
class QualityMetadataV1:
    """Deterministic evidence sufficiency for a result or individual metric."""

    supported: bool
    unsupported: bool
    confidence: DeterministicConfidence
    missing_data: tuple[MissingDataReason, ...]
    review_status: AnalyticsReviewStatus
    incomplete_timeline: bool
    schema_version: Literal["analytics-quality-metadata.v1"] = "analytics-quality-metadata.v1"

    def __post_init__(self) -> None:
        if self.supported == self.unsupported:
            raise ValueError("supported and unsupported must be complementary")
        if self.unsupported and self.confidence != DeterministicConfidence.UNAVAILABLE:
            raise ValueError("unsupported metrics must use unavailable confidence")


@dataclass(frozen=True, slots=True)
class MetricDefinitionV1:
    """Canonical reproducible definition for one Phase 6B metric."""

    identifier: str
    description: str
    formula: str
    included_event_types: tuple[ConversationEventType, ...]
    excluded_event_types: tuple[ConversationEventType, ...]
    required_fields: tuple[str, ...]
    unsupported_conditions: tuple[MissingDataReason, ...]
    schema_version: Literal["analytics-metric-definition.v1"] = "analytics-metric-definition.v1"


@dataclass(frozen=True, slots=True)
class ReactionTypeCountV1:
    """One accepted reaction metadata value and its structural evidence."""

    reaction_type: str
    count: int
    evidence: EvidenceReferenceV1
    schema_version: Literal["analytics-reaction-type-count.v1"] = "analytics-reaction-type-count.v1"


type MetricValue = int | float | UUID | tuple[ReactionTypeCountV1, ...] | None


@dataclass(frozen=True, slots=True)
class MetricV1:
    """A value, its complete definition, content-free evidence, and quality."""

    definition: MetricDefinitionV1
    value: MetricValue
    unit: MetricUnit
    evidence: EvidenceReferenceV1
    quality: QualityMetadataV1
    schema_version: Literal["analytics-metric.v1"] = "analytics-metric.v1"

    def __post_init__(self) -> None:
        if self.quality.unsupported and self.value is not None:
            raise ValueError("unsupported metrics cannot expose a calculated value")


@dataclass(frozen=True, slots=True)
class ConversationAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["conversation-analytics-section.v1"] = (
        "conversation-analytics-section.v1"
    )


@dataclass(frozen=True, slots=True)
class MessageAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["message-analytics-section.v1"] = "message-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class ParticipantAnalyticsV1:
    speaker: ConversationEventSpeaker
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["participant-analytics-section.v1"] = "participant-analytics-section.v1"

    def __post_init__(self) -> None:
        if self.speaker not in {
            ConversationEventSpeaker.USER,
            ConversationEventSpeaker.OTHER,
        }:
            raise ValueError("participant analytics require user or other speaker")


@dataclass(frozen=True, slots=True)
class TimelineAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["timeline-analytics-section.v1"] = "timeline-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class QuestionAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["question-analytics-section.v1"] = "question-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class ReplyAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["reply-analytics-section.v1"] = "reply-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class ReactionAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["reaction-analytics-section.v1"] = "reaction-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class MediaAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["media-analytics-section.v1"] = "media-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class StructureAnalyticsV1:
    metrics: tuple[MetricV1, ...]
    schema_version: Literal["structure-analytics-section.v1"] = "structure-analytics-section.v1"


@dataclass(frozen=True, slots=True)
class AnalyticsResultV1:
    """Derived Phase 6B result; intentionally contains no generation timestamp."""

    conversation: ConversationAnalyticsV1
    messages: MessageAnalyticsV1
    participants: tuple[ParticipantAnalyticsV1, ParticipantAnalyticsV1]
    timeline: TimelineAnalyticsV1
    questions: QuestionAnalyticsV1
    replies: ReplyAnalyticsV1
    reactions: ReactionAnalyticsV1
    media: MediaAnalyticsV1
    structure: StructureAnalyticsV1
    quality: QualityMetadataV1
    source_schema_version: SourceEventSchemaVersion = "conversation-events.v1"
    calculation_version: AnalyticsCalculationVersion = "deterministic-conversation-analytics.v1"
    schema_version: AnalyticsSchemaVersion = "conversation-analytics.v1"

    def __post_init__(self) -> None:
        if self.schema_version != ANALYTICS_SCHEMA_VERSION:
            raise ValueError("unsupported analytics result schema version")
        if self.calculation_version != ANALYTICS_CALCULATION_VERSION:
            raise ValueError("unsupported analytics calculation version")
        if self.source_schema_version != "conversation-events.v1":
            raise ValueError("unsupported analytics source schema version")

    @property
    def all_metrics(self) -> tuple[MetricV1, ...]:
        """Return metrics in a stable category and participant order."""
        return (
            *self.conversation.metrics,
            *self.messages.metrics,
            *(metric for participant in self.participants for metric in participant.metrics),
            *self.timeline.metrics,
            *self.questions.metrics,
            *self.replies.metrics,
            *self.reactions.metrics,
            *self.media.metrics,
            *self.structure.metrics,
        )
