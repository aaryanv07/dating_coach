"""Deterministic placeholder generator for structured-response testing only."""

from uuid import NAMESPACE_URL, UUID, uuid5

from app.ai.coaching_response_contracts import (
    CoachingCapabilitiesV1,
    CoachingCapability,
    CoachingConfidenceDescriptor,
    CoachingEvidenceLinkV1,
    CoachingExplanationStatus,
    CoachingExplanationV1,
    CoachingResponseMetadataV1,
    CoachingResponseProvenanceV1,
    CoachingSafetyNoticeCode,
    CoachingSafetyNoticeV1,
    CoachingSafetySeverity,
    CoachingUnavailableCapabilityV1,
    CoachingUnavailableReason,
    StructuredCoachingResponseV1,
)
from app.ai.contracts import AIEvidencePackageV1

_FOUNDATION_CAPABILITIES = (
    CoachingCapability.RESPONSE_SCHEMA,
    CoachingCapability.EVIDENCE_REFERENCES,
    CoachingCapability.EXPLANATION_PLACEHOLDERS,
    CoachingCapability.SAFETY_NOTICES,
)
_UNAVAILABLE_CAPABILITIES = (
    CoachingCapability.COACHING_GUIDANCE,
    CoachingCapability.RECOMMENDATIONS,
    CoachingCapability.REPLY_DRAFTING,
    CoachingCapability.FIRST_MESSAGE_DRAFTING,
    CoachingCapability.COMMUNICATION_DNA,
    CoachingCapability.RELATIONSHIP_SCORING,
    CoachingCapability.COMPATIBILITY_SCORING,
)


class DeterministicCoachingResponseMock:
    """Generate schema-valid placeholders without advice or prompt execution."""

    identifier = "deterministic-coaching-response-mock.v1"

    def generate(
        self,
        *,
        response_id: UUID,
        request_id: UUID,
        evidence_package_id: UUID,
        evidence: AIEvidencePackageV1,
        locale: str = "en",
    ) -> StructuredCoachingResponseV1:
        evidence_link_id = uuid5(
            NAMESPACE_URL,
            f"convocoach:evidence-link:{evidence_package_id}",
        )
        explanation_id = uuid5(
            NAMESPACE_URL,
            f"convocoach:explanation-placeholder:{evidence_package_id}",
        )
        evidence_link = CoachingEvidenceLinkV1(
            link_id=evidence_link_id,
            evidence_package_id=evidence_package_id,
            event_ids=tuple(event.event_id for event in evidence.context.events),
            relationship_ids=tuple(
                relationship.relationship_id for relationship in evidence.context.relationships
            ),
            metric_identifiers=tuple(metric.identifier for metric in evidence.analytics),
            analytics_schema_version=evidence.analytics_schema_version,
            analytics_calculation_version=evidence.analytics_calculation_version,
        )
        return StructuredCoachingResponseV1(
            metadata=CoachingResponseMetadataV1(
                response_id=response_id,
                request_id=request_id,
                locale=locale,
            ),
            capabilities=CoachingCapabilitiesV1(
                supported=_FOUNDATION_CAPABILITIES,
                unavailable=tuple(
                    CoachingUnavailableCapabilityV1(
                        capability=capability,
                        reason=CoachingUnavailableReason.NOT_IMPLEMENTED,
                    )
                    for capability in _UNAVAILABLE_CAPABILITIES
                ),
            ),
            evidence_links=(evidence_link,),
            explanations=(
                CoachingExplanationV1(
                    explanation_id=explanation_id,
                    capability=CoachingCapability.EXPLANATION_PLACEHOLDERS,
                    status=CoachingExplanationStatus.PLACEHOLDER,
                    localization_key="coaching.foundation.placeholder",
                    evidence_link_ids=(evidence_link_id,),
                    confidence=CoachingConfidenceDescriptor.NOT_APPLICABLE,
                ),
            ),
            safety_notices=(
                CoachingSafetyNoticeV1(
                    code=CoachingSafetyNoticeCode.NO_COACHING_GENERATED,
                    severity=CoachingSafetySeverity.INFORMATION,
                    localization_key="coaching.foundation.no_coaching_generated",
                ),
            ),
            provenance=CoachingResponseProvenanceV1(
                generator_identifier=self.identifier,
                source_evidence_schema_version=evidence.schema_version,
                analytics_schema_version=evidence.analytics_schema_version,
                analytics_calculation_version=evidence.analytics_calculation_version,
            ),
        )
