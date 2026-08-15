"""Immutable provider-neutral contracts for structured coaching responses."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from uuid import UUID

AI_COACHING_RESPONSE_SCHEMA_VERSION = "ai-coaching-response.v1"


class CoachingCapability(StrEnum):
    """Closed capability registry for schema validation and future negotiation."""

    RESPONSE_SCHEMA = "response_schema"
    EVIDENCE_REFERENCES = "evidence_references"
    EXPLANATION_PLACEHOLDERS = "explanation_placeholders"
    SAFETY_NOTICES = "safety_notices"
    COACHING_GUIDANCE = "coaching_guidance"
    RECOMMENDATIONS = "recommendations"
    REPLY_DRAFTING = "reply_drafting"
    FIRST_MESSAGE_DRAFTING = "first_message_drafting"
    COMMUNICATION_DNA = "communication_dna"
    RELATIONSHIP_SCORING = "relationship_scoring"
    COMPATIBILITY_SCORING = "compatibility_scoring"


class CoachingUnavailableReason(StrEnum):
    NOT_IMPLEMENTED = "not_implemented"
    INSUFFICIENT_EVIDENCE = "insufficient_evidence"
    UNSUPPORTED_DATA = "unsupported_data"
    SAFETY_RESTRICTED = "safety_restricted"


class CoachingExplanationStatus(StrEnum):
    PLACEHOLDER = "placeholder"
    UNAVAILABLE = "unavailable"


class CoachingConfidenceDescriptor(StrEnum):
    """Evidence sufficiency descriptor, never confidence about another person."""

    NOT_APPLICABLE = "not_applicable"
    EVIDENCE_COMPLETE = "evidence_complete"
    EVIDENCE_REDUCED = "evidence_reduced"
    EVIDENCE_UNAVAILABLE = "evidence_unavailable"


class CoachingSafetyNoticeCode(StrEnum):
    NO_COACHING_GENERATED = "no_coaching_generated"
    HUMAN_REVIEW_REQUIRED = "human_review_required"
    DATA_QUALITY_LIMITATION = "data_quality_limitation"


class CoachingSafetySeverity(StrEnum):
    INFORMATION = "information"
    CAUTION = "caution"


@dataclass(frozen=True, slots=True)
class CoachingResponseMetadataV1:
    response_id: UUID
    request_id: UUID
    locale: str
    schema_version: Literal["ai-coaching-response-metadata.v1"] = "ai-coaching-response-metadata.v1"


@dataclass(frozen=True, slots=True)
class CoachingUnavailableCapabilityV1:
    capability: CoachingCapability
    reason: CoachingUnavailableReason
    schema_version: Literal["ai-coaching-unavailable-capability.v1"] = (
        "ai-coaching-unavailable-capability.v1"
    )


@dataclass(frozen=True, slots=True)
class CoachingCapabilitiesV1:
    supported: tuple[CoachingCapability, ...]
    unavailable: tuple[CoachingUnavailableCapabilityV1, ...]
    schema_version: Literal["ai-coaching-capabilities.v1"] = "ai-coaching-capabilities.v1"


@dataclass(frozen=True, slots=True)
class CoachingEvidenceLinkV1:
    link_id: UUID
    evidence_package_id: UUID
    event_ids: tuple[UUID, ...]
    relationship_ids: tuple[UUID, ...]
    metric_identifiers: tuple[str, ...]
    analytics_schema_version: str
    analytics_calculation_version: str
    schema_version: Literal["ai-coaching-evidence-link.v1"] = "ai-coaching-evidence-link.v1"


@dataclass(frozen=True, slots=True)
class CoachingExplanationV1:
    explanation_id: UUID
    capability: CoachingCapability
    status: CoachingExplanationStatus
    localization_key: str
    evidence_link_ids: tuple[UUID, ...]
    confidence: CoachingConfidenceDescriptor
    schema_version: Literal["ai-coaching-explanation.v1"] = "ai-coaching-explanation.v1"


@dataclass(frozen=True, slots=True)
class CoachingSafetyNoticeV1:
    code: CoachingSafetyNoticeCode
    severity: CoachingSafetySeverity
    localization_key: str
    evidence_link_ids: tuple[UUID, ...] = ()
    schema_version: Literal["ai-coaching-safety-notice.v1"] = "ai-coaching-safety-notice.v1"


@dataclass(frozen=True, slots=True)
class CoachingResponseProvenanceV1:
    generator_identifier: str
    source_evidence_schema_version: str
    analytics_schema_version: str
    analytics_calculation_version: str
    schema_version: Literal["ai-coaching-provenance.v1"] = "ai-coaching-provenance.v1"


@dataclass(frozen=True, slots=True)
class StructuredCoachingResponseV1:
    metadata: CoachingResponseMetadataV1
    capabilities: CoachingCapabilitiesV1
    evidence_links: tuple[CoachingEvidenceLinkV1, ...]
    explanations: tuple[CoachingExplanationV1, ...]
    safety_notices: tuple[CoachingSafetyNoticeV1, ...]
    provenance: CoachingResponseProvenanceV1
    schema_version: Literal["ai-coaching-response.v1"] = "ai-coaching-response.v1"


class CoachingResponseValidationFailureCode(StrEnum):
    INVALID_SCHEMA_VERSION = "invalid_schema_version"
    DUPLICATE_IDENTIFIER = "duplicate_identifier"
    UNSUPPORTED_CAPABILITY = "unsupported_capability"
    CAPABILITY_STATUS_CONFLICT = "capability_status_conflict"
    EVIDENCE_PACKAGE_MISMATCH = "evidence_package_mismatch"
    MISSING_EVIDENCE_REFERENCE = "missing_evidence_reference"
    FORBIDDEN_EVENT_REFERENCE = "forbidden_event_reference"
    FORBIDDEN_RELATIONSHIP_REFERENCE = "forbidden_relationship_reference"
    FORBIDDEN_METRIC_REFERENCE = "forbidden_metric_reference"
    ANALYTICS_VERSION_MISMATCH = "analytics_version_mismatch"
    INVALID_LOCALIZATION_KEY = "invalid_localization_key"
    INVALID_PLACEHOLDER = "invalid_placeholder"


@dataclass(frozen=True, slots=True)
class CoachingResponseValidationFailureV1:
    code: CoachingResponseValidationFailureCode
    reference: str | None = None
    schema_version: Literal["ai-coaching-response-validation-failure.v1"] = (
        "ai-coaching-response-validation-failure.v1"
    )


class CoachingResponseParseFailureCode(StrEnum):
    INVALID_JSON = "invalid_json"
    INVALID_SHAPE = "invalid_shape"
    FORBIDDEN_FIELD = "forbidden_field"
    INVALID_VALUE = "invalid_value"


@dataclass(frozen=True, slots=True)
class CoachingResponseParseFailureV1:
    code: CoachingResponseParseFailureCode
    field_name: str | None = None
    schema_version: Literal["ai-coaching-response-parse-failure.v1"] = (
        "ai-coaching-response-parse-failure.v1"
    )


@dataclass(frozen=True, slots=True)
class CoachingResponseParseSuccessV1:
    response: StructuredCoachingResponseV1
    schema_version: Literal["ai-coaching-response-parse-success.v1"] = (
        "ai-coaching-response-parse-success.v1"
    )


type CoachingResponseParseResultV1 = CoachingResponseParseFailureV1 | CoachingResponseParseSuccessV1
