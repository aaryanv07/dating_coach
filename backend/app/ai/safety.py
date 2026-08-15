"""Fail-closed Phase 8 request validation."""

from app.ai.contracts import (
    AI_CONTEXT_SCHEMA_VERSION,
    AI_EVIDENCE_SCHEMA_VERSION,
    AI_METRIC_EVIDENCE_SCHEMA_VERSION,
    AI_PROMPT_TEMPLATE_SCHEMA_VERSION,
    AIEvidencePackageV1,
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestRequirementsV1,
    AISafetyFailureCode,
    AISafetyFailureV1,
)
from app.domain.conversation_analytics import (
    ANALYTICS_CALCULATION_VERSION,
    ANALYTICS_SCHEMA_VERSION,
    AnalyticsInputV1,
)

_UNKNOWN_EVENTS_METRIC = "structure.unknown_events"


def _schema_mismatch(actual: str, expected: str) -> bool:
    """Keep runtime boundary validation visible to strict static typing."""
    return actual != expected


class AIRequestSafetyValidator:
    """Validate readiness, evidence sufficiency, versions, and explicit intent."""

    def validate(
        self,
        source: AnalyticsInputV1,
        evidence: AIEvidencePackageV1,
        requirements: AIRequestRequirementsV1,
        template: AIPromptTemplateV1,
        intent: AIRequestIntentV1,
    ) -> tuple[AISafetyFailureV1, ...]:
        failures: list[AISafetyFailureV1] = []

        if (
            evidence.context.schema_version != AI_CONTEXT_SCHEMA_VERSION
            or any(
                event.schema_version != "ai-event-evidence.v1" for event in evidence.context.events
            )
            or any(
                relationship.schema_version != "ai-relationship-evidence.v1"
                for relationship in evidence.context.relationships
            )
        ):
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INVALID_CONTEXT_SCHEMA))
        if evidence.schema_version != AI_EVIDENCE_SCHEMA_VERSION:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INVALID_EVIDENCE_SCHEMA))
        if _schema_mismatch(
            requirements.schema_version,
            "ai-request-requirements.v1",
        ):
            failures.append(
                AISafetyFailureV1(AISafetyFailureCode.INVALID_REQUEST_REQUIREMENTS_SCHEMA)
            )
        if template.schema_version != AI_PROMPT_TEMPLATE_SCHEMA_VERSION:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INVALID_PROMPT_TEMPLATE_SCHEMA))
        if _schema_mismatch(intent.schema_version, "ai-request-intent.v1"):
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INVALID_REQUEST_INTENT_SCHEMA))
        if "evidence" not in template.input_slots:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.REQUIRED_EVIDENCE_MISSING))
        if (
            evidence.analytics_schema_version != ANALYTICS_SCHEMA_VERSION
            or evidence.analytics_calculation_version != ANALYTICS_CALCULATION_VERSION
            or evidence.context.source_event_schema_version != "conversation-events.v1"
            or any(
                metric.schema_version != AI_METRIC_EVIDENCE_SCHEMA_VERSION
                for metric in evidence.analytics
            )
        ):
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INVALID_ANALYTICS_SCHEMA))
        if source.review_status.value != "confirmed":
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INCOMPLETE_REVIEW))
        if requirements.require_complete_timeline and source.timeline_gaps:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.INCOMPLETE_TIMELINE))
        if source.is_partial:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.PARTIAL_CONVERSATION))
        if intent.requests_deleted_content_reconstruction:
            failures.append(
                AISafetyFailureV1(AISafetyFailureCode.DELETED_CONTENT_RECONSTRUCTION_REQUESTED)
            )

        metrics = {metric.identifier: metric for metric in evidence.analytics}
        for identifier in requirements.required_metric_identifiers:
            metric = metrics.get(identifier)
            if metric is None:
                failures.append(
                    AISafetyFailureV1(
                        AISafetyFailureCode.REQUIRED_ANALYTICS_MISSING,
                        identifier,
                    )
                )
                continue
            if metric.quality.unsupported:
                failures.append(
                    AISafetyFailureV1(
                        AISafetyFailureCode.REQUIRED_ANALYTICS_UNSUPPORTED,
                        identifier,
                    )
                )
            if metric.value is None:
                failures.append(
                    AISafetyFailureV1(
                        AISafetyFailureCode.REQUIRED_EVIDENCE_MISSING,
                        identifier,
                    )
                )
            if (
                identifier != _UNKNOWN_EVENTS_METRIC
                and metric.value not in (0, 0.0, None)
                and not metric.event_ids
                and not metric.relationship_ids
            ):
                failures.append(
                    AISafetyFailureV1(
                        AISafetyFailureCode.REQUIRED_EVIDENCE_MISSING,
                        identifier,
                    )
                )
        if requirements.require_event_evidence and not evidence.context.events:
            failures.append(AISafetyFailureV1(AISafetyFailureCode.EVENT_EVIDENCE_MISSING))

        unknown_metric = metrics.get(_UNKNOWN_EVENTS_METRIC)
        unknown_value = unknown_metric.value if unknown_metric is not None else None
        if (
            unknown_metric is None
            or unknown_metric.quality.unsupported
            or not isinstance(unknown_value, int)
        ):
            failures.append(
                AISafetyFailureV1(
                    AISafetyFailureCode.UNKNOWN_EVENT_THRESHOLD_UNAVAILABLE,
                    _UNKNOWN_EVENTS_METRIC,
                )
            )
        elif unknown_value > requirements.maximum_unknown_events:
            failures.append(
                AISafetyFailureV1(
                    AISafetyFailureCode.UNKNOWN_EVENT_THRESHOLD_EXCEEDED,
                    _UNKNOWN_EVENTS_METRIC,
                )
            )

        return tuple(
            sorted(
                set(failures),
                key=lambda failure: (
                    failure.code.value,
                    failure.metric_identifier or "",
                ),
            )
        )
