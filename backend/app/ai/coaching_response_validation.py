"""Fail-closed validation for structured coaching-response contracts."""

from uuid import UUID

from app.ai.coaching_response_contracts import (
    AI_COACHING_RESPONSE_SCHEMA_VERSION,
    CoachingCapability,
    CoachingExplanationStatus,
    CoachingResponseValidationFailureCode,
    CoachingResponseValidationFailureV1,
    StructuredCoachingResponseV1,
)
from app.ai.contracts import AIEvidencePackageV1

_ALLOWED_EXPLANATION_KEYS = frozenset(
    {
        "coaching.foundation.placeholder",
        "coaching.unavailable.not_implemented",
        "coaching.unavailable.insufficient_evidence",
        "coaching.unavailable.unsupported_data",
        "coaching.unavailable.safety_restricted",
    }
)
_ALLOWED_SAFETY_KEYS = frozenset(
    {
        "coaching.foundation.no_coaching_generated",
        "coaching.safety.human_review_required",
        "coaching.safety.data_quality_limitation",
    }
)


def _schema_mismatch(actual: str, expected: str) -> bool:
    return actual != expected


def _unique(values: tuple[object, ...]) -> bool:
    return len(set(values)) == len(values)


class StructuredCoachingResponseValidator:
    """Validate versions, capability registry, and evidence provenance."""

    def validate(
        self,
        response: StructuredCoachingResponseV1,
        *,
        evidence_package_id: UUID,
        evidence: AIEvidencePackageV1,
    ) -> tuple[CoachingResponseValidationFailureV1, ...]:
        failures: list[CoachingResponseValidationFailureV1] = []
        versions = (
            (response.schema_version, AI_COACHING_RESPONSE_SCHEMA_VERSION),
            (
                response.metadata.schema_version,
                "ai-coaching-response-metadata.v1",
            ),
            (
                response.capabilities.schema_version,
                "ai-coaching-capabilities.v1",
            ),
            (
                response.provenance.schema_version,
                "ai-coaching-provenance.v1",
            ),
            *(
                (link.schema_version, "ai-coaching-evidence-link.v1")
                for link in response.evidence_links
            ),
            *(
                (explanation.schema_version, "ai-coaching-explanation.v1")
                for explanation in response.explanations
            ),
            *(
                (notice.schema_version, "ai-coaching-safety-notice.v1")
                for notice in response.safety_notices
            ),
            *(
                (
                    unavailable.schema_version,
                    "ai-coaching-unavailable-capability.v1",
                )
                for unavailable in response.capabilities.unavailable
            ),
        )
        if any(_schema_mismatch(actual, expected) for actual, expected in versions):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.INVALID_SCHEMA_VERSION
                )
            )

        supported = response.capabilities.supported
        unavailable = tuple(item.capability for item in response.capabilities.unavailable)
        if not _unique((*supported, *unavailable)):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.DUPLICATE_IDENTIFIER,
                    "capability",
                )
            )
        if set(supported) & set(unavailable):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.CAPABILITY_STATUS_CONFLICT
                )
            )
        if any(
            not isinstance(capability, CoachingCapability)
            for capability in (*supported, *unavailable)
        ):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.UNSUPPORTED_CAPABILITY
                )
            )

        link_ids = tuple(link.link_id for link in response.evidence_links)
        explanation_ids = tuple(explanation.explanation_id for explanation in response.explanations)
        if not _unique(link_ids) or not _unique(explanation_ids):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.DUPLICATE_IDENTIFIER,
                    "response_section",
                )
            )

        allowed_event_ids = {event.event_id for event in evidence.context.events}
        allowed_relationship_ids = {
            relationship.relationship_id for relationship in evidence.context.relationships
        }
        allowed_metric_ids = {metric.identifier for metric in evidence.analytics}
        for link in response.evidence_links:
            if link.evidence_package_id != evidence_package_id:
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.EVIDENCE_PACKAGE_MISMATCH,
                        str(link.link_id),
                    )
                )
            if not set(link.event_ids).issubset(allowed_event_ids):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.FORBIDDEN_EVENT_REFERENCE,
                        str(link.link_id),
                    )
                )
            if not set(link.relationship_ids).issubset(allowed_relationship_ids):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.FORBIDDEN_RELATIONSHIP_REFERENCE,
                        str(link.link_id),
                    )
                )
            if not set(link.metric_identifiers).issubset(allowed_metric_ids):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.FORBIDDEN_METRIC_REFERENCE,
                        str(link.link_id),
                    )
                )
            if (
                link.analytics_schema_version != evidence.analytics_schema_version
                or link.analytics_calculation_version != evidence.analytics_calculation_version
            ):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.ANALYTICS_VERSION_MISMATCH,
                        str(link.link_id),
                    )
                )

        available_link_ids = set(link_ids)
        for explanation in response.explanations:
            if not set(explanation.evidence_link_ids).issubset(available_link_ids):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.MISSING_EVIDENCE_REFERENCE,
                        str(explanation.explanation_id),
                    )
                )
            if explanation.localization_key not in _ALLOWED_EXPLANATION_KEYS:
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.INVALID_LOCALIZATION_KEY,
                        str(explanation.explanation_id),
                    )
                )
            if explanation.status == CoachingExplanationStatus.PLACEHOLDER and (
                explanation.capability != CoachingCapability.EXPLANATION_PLACEHOLDERS
                or explanation.localization_key != "coaching.foundation.placeholder"
            ):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.INVALID_PLACEHOLDER,
                        str(explanation.explanation_id),
                    )
                )

        for notice in response.safety_notices:
            if not set(notice.evidence_link_ids).issubset(available_link_ids):
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.MISSING_EVIDENCE_REFERENCE,
                        notice.code.value,
                    )
                )
            if notice.localization_key not in _ALLOWED_SAFETY_KEYS:
                failures.append(
                    CoachingResponseValidationFailureV1(
                        CoachingResponseValidationFailureCode.INVALID_LOCALIZATION_KEY,
                        notice.code.value,
                    )
                )

        if (
            response.provenance.source_evidence_schema_version != evidence.schema_version
            or response.provenance.analytics_schema_version != evidence.analytics_schema_version
            or response.provenance.analytics_calculation_version
            != evidence.analytics_calculation_version
        ):
            failures.append(
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.ANALYTICS_VERSION_MISMATCH,
                    "provenance",
                )
            )

        return tuple(
            sorted(
                set(failures),
                key=lambda failure: (
                    failure.code.value,
                    failure.reference or "",
                ),
            )
        )
