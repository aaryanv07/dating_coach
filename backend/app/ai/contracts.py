"""Immutable, versioned contracts for provider-neutral AI orchestration."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from uuid import UUID

from app.domain.conversation_analytics import MetricUnit, MetricValue, QualityMetadataV1
from app.domain.conversation_events import (
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
)

AI_CONTEXT_SCHEMA_VERSION = "ai-conversation-context.v1"
AI_EVIDENCE_SCHEMA_VERSION = "ai-evidence-package.v1"
AI_METRIC_EVIDENCE_SCHEMA_VERSION = "ai-analytics-metric-evidence.v1"
AI_PROMPT_TEMPLATE_SCHEMA_VERSION = "ai-prompt-template.v1"
AI_REQUEST_SCHEMA_VERSION = "ai-request.v1"
AI_RAW_RESPONSE_SCHEMA_VERSION = "ai-raw-provider-response.v1"
AI_RESPONSE_SCHEMA_VERSION = "ai-response.v1"


class AIRequestPurpose(StrEnum):
    """Closed Phase 8 intent vocabulary."""

    FOUNDATION_VALIDATION = "foundation_validation"


class AIResponseStatus(StrEnum):
    """Closed Phase 8 response vocabulary."""

    FOUNDATION_PLACEHOLDER = "foundation_placeholder"


class AISafetyFailureCode(StrEnum):
    """Stable fail-closed request rejection reasons."""

    INVALID_CONTEXT_SCHEMA = "invalid_context_schema"
    INVALID_EVIDENCE_SCHEMA = "invalid_evidence_schema"
    INVALID_ANALYTICS_SCHEMA = "invalid_analytics_schema"
    INVALID_REQUEST_REQUIREMENTS_SCHEMA = "invalid_request_requirements_schema"
    INVALID_PROMPT_TEMPLATE_SCHEMA = "invalid_prompt_template_schema"
    INVALID_REQUEST_INTENT_SCHEMA = "invalid_request_intent_schema"
    INCOMPLETE_REVIEW = "incomplete_review"
    INCOMPLETE_TIMELINE = "incomplete_timeline"
    PARTIAL_CONVERSATION = "partial_conversation"
    REQUIRED_ANALYTICS_MISSING = "required_analytics_missing"
    REQUIRED_ANALYTICS_UNSUPPORTED = "required_analytics_unsupported"
    REQUIRED_EVIDENCE_MISSING = "required_evidence_missing"
    EVENT_EVIDENCE_MISSING = "event_evidence_missing"
    UNKNOWN_EVENT_THRESHOLD_UNAVAILABLE = "unknown_event_threshold_unavailable"
    UNKNOWN_EVENT_THRESHOLD_EXCEEDED = "unknown_event_threshold_exceeded"
    DELETED_CONTENT_RECONSTRUCTION_REQUESTED = "deleted_content_reconstruction_requested"


class AIProcessingFailureCode(StrEnum):
    """Safe orchestration failures that never include provider payloads."""

    PROVIDER_FAILURE = "provider_failure"
    INVALID_PROVIDER_RESPONSE = "invalid_provider_response"


@dataclass(frozen=True, slots=True)
class AIEventEvidenceV1:
    """Content-free structural evidence for one reviewed canonical event."""

    event_id: UUID
    position: int
    event_type: ConversationEventType
    speaker: ConversationEventSpeaker
    has_exact_timestamp: bool
    schema_version: Literal["ai-event-evidence.v1"] = "ai-event-evidence.v1"


@dataclass(frozen=True, slots=True)
class AIRelationshipEvidenceV1:
    """Content-free structural evidence for one reviewed event relationship."""

    relationship_id: UUID
    source_event_id: UUID
    target_event_id: UUID
    relationship_type: ConversationEventRelationshipType
    schema_version: Literal["ai-relationship-evidence.v1"] = "ai-relationship-evidence.v1"


@dataclass(frozen=True, slots=True)
class AIConversationContextV1:
    """Reviewed canonical structural context; message content is intentionally absent."""

    events: tuple[AIEventEvidenceV1, ...]
    relationships: tuple[AIRelationshipEvidenceV1, ...]
    source_event_schema_version: str
    schema_version: Literal["ai-conversation-context.v1"] = "ai-conversation-context.v1"


@dataclass(frozen=True, slots=True)
class AIAnalyticsMetricEvidenceV1:
    """Minimum deterministic value, evidence references, and quality metadata."""

    identifier: str
    value: MetricValue
    unit: MetricUnit
    event_ids: tuple[UUID, ...]
    relationship_ids: tuple[UUID, ...]
    quality: QualityMetadataV1
    schema_version: Literal["ai-analytics-metric-evidence.v1"] = "ai-analytics-metric-evidence.v1"


@dataclass(frozen=True, slots=True)
class AIEvidencePackageV1:
    """Provider-neutral content-minimized evidence input."""

    context: AIConversationContextV1
    analytics: tuple[AIAnalyticsMetricEvidenceV1, ...]
    analytics_schema_version: str
    analytics_calculation_version: str
    schema_version: Literal["ai-evidence-package.v1"] = "ai-evidence-package.v1"


@dataclass(frozen=True, slots=True)
class AIRequestRequirementsV1:
    """Explicit request preconditions; no hidden heuristic thresholds."""

    required_metric_identifiers: tuple[str, ...]
    maximum_unknown_events: int = 0
    require_complete_timeline: bool = True
    require_event_evidence: bool = True
    schema_version: Literal["ai-request-requirements.v1"] = "ai-request-requirements.v1"

    def __post_init__(self) -> None:
        if self.maximum_unknown_events < 0:
            raise ValueError("maximum_unknown_events must not be negative")
        if len(set(self.required_metric_identifiers)) != len(self.required_metric_identifiers):
            raise ValueError("required metric identifiers must be unique")


@dataclass(frozen=True, slots=True)
class AIPromptTemplateV1:
    """Versioned localizable prompt contract descriptor, never prompt text."""

    identifier: str
    template_version: str
    locale: str
    input_slots: tuple[str, ...]
    schema_version: Literal["ai-prompt-template.v1"] = "ai-prompt-template.v1"


@dataclass(frozen=True, slots=True)
class AIRequestIntentV1:
    """Explicit request purpose and prohibited reconstruction behavior."""

    purpose: AIRequestPurpose
    requests_deleted_content_reconstruction: bool = False
    schema_version: Literal["ai-request-intent.v1"] = "ai-request-intent.v1"


@dataclass(frozen=True, slots=True)
class AIRequestV1:
    """Immutable provider request contract."""

    request_id: UUID
    template: AIPromptTemplateV1
    intent: AIRequestIntentV1
    evidence: AIEvidencePackageV1
    schema_version: Literal["ai-request.v1"] = "ai-request.v1"


@dataclass(frozen=True, slots=True)
class AISafetyFailureV1:
    code: AISafetyFailureCode
    metric_identifier: str | None = None
    schema_version: Literal["ai-safety-failure.v1"] = "ai-safety-failure.v1"


@dataclass(frozen=True, slots=True)
class AIRawProviderResponseV1:
    """Raw provider boundary. Its payload must never be logged."""

    payload: str
    provider_identifier: str
    schema_version: Literal["ai-raw-provider-response.v1"] = "ai-raw-provider-response.v1"


@dataclass(frozen=True, slots=True)
class AIResponseV1:
    """Validated structured Phase 8 placeholder response."""

    provider_identifier: str
    status: AIResponseStatus
    request_schema_version: str
    prompt_identifier: str
    prompt_template_version: str
    evidence_event_ids: tuple[UUID, ...]
    limitations: tuple[str, ...]
    schema_version: Literal["ai-response.v1"] = "ai-response.v1"


@dataclass(frozen=True, slots=True)
class AIOrchestrationDisabledV1:
    schema_version: Literal["ai-orchestration-disabled.v1"] = "ai-orchestration-disabled.v1"


@dataclass(frozen=True, slots=True)
class AIOrchestrationRejectedV1:
    failures: tuple[AISafetyFailureV1, ...]
    schema_version: Literal["ai-orchestration-rejected.v1"] = "ai-orchestration-rejected.v1"


@dataclass(frozen=True, slots=True)
class AIOrchestrationProcessingFailureV1:
    code: AIProcessingFailureCode
    schema_version: Literal["ai-orchestration-processing-failure.v1"] = (
        "ai-orchestration-processing-failure.v1"
    )


@dataclass(frozen=True, slots=True)
class AIOrchestrationCompletedV1:
    response: AIResponseV1
    schema_version: Literal["ai-orchestration-completed.v1"] = "ai-orchestration-completed.v1"


type AIOrchestrationResultV1 = (
    AIOrchestrationDisabledV1
    | AIOrchestrationRejectedV1
    | AIOrchestrationProcessingFailureV1
    | AIOrchestrationCompletedV1
)
