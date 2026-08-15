"""Deterministic, content-minimized evidence packaging."""

from app.ai.contracts import (
    AIAnalyticsMetricEvidenceV1,
    AIConversationContextV1,
    AIEventEvidenceV1,
    AIEvidencePackageV1,
    AIRelationshipEvidenceV1,
    AIRequestRequirementsV1,
)
from app.domain.conversation_analytics import AnalyticsResultV1
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventSequence,
    ConversationEventRelationshipType,
    ConversationEventType,
)

_EXCLUDED_EVENT_TYPES = frozenset(
    {
        ConversationEventType.DELETED_MESSAGE,
        ConversationEventType.EDITED_MESSAGE_MARKER,
        ConversationEventType.UNKNOWN,
    }
)


def _eligible_event(event: ConfirmedConversationEvent) -> bool:
    return (
        event.deleted_at is None
        and not event.requires_review
        and event.event_type not in _EXCLUDED_EVENT_TYPES
    )


class AIEvidenceBuilder:
    """Project canonical events and deterministic analytics without raw content."""

    def build(
        self,
        sequence: ConfirmedConversationEventSequence,
        analytics: AnalyticsResultV1,
        requirements: AIRequestRequirementsV1,
    ) -> AIEvidencePackageV1:
        duplicate_source_ids = {
            relationship.source_event_id
            for relationship in sequence.relationships
            if relationship.relationship_type == ConversationEventRelationshipType.DUPLICATE_OF
            and relationship.source_event_id != relationship.target_event_id
            and any(event.id == relationship.target_event_id for event in sequence.events)
        }
        eligible = tuple(
            sorted(
                (
                    event
                    for event in sequence.events
                    if _eligible_event(event) and event.id not in duplicate_source_ids
                ),
                key=lambda event: (event.position, str(event.id)),
            )
        )
        event_ids = {event.id for event in eligible}
        events = tuple(
            AIEventEvidenceV1(
                event_id=event.id,
                position=event.position,
                event_type=event.event_type,
                speaker=event.speaker,
                has_exact_timestamp=(
                    event.timestamp is not None and not event.timestamp_is_estimated
                ),
            )
            for event in eligible
        )
        relationships = tuple(
            AIRelationshipEvidenceV1(
                relationship_id=relationship.id,
                source_event_id=relationship.source_event_id,
                target_event_id=relationship.target_event_id,
                relationship_type=relationship.relationship_type,
            )
            for relationship in sorted(
                sequence.relationships,
                key=lambda relationship: str(relationship.id),
            )
            if relationship.source_event_id in event_ids
            and relationship.target_event_id in event_ids
            and relationship.relationship_type != ConversationEventRelationshipType.DUPLICATE_OF
        )
        relationship_ids = {relationship.relationship_id for relationship in relationships}
        metrics_by_identifier = {
            metric.definition.identifier: metric for metric in analytics.all_metrics
        }
        metric_evidence = tuple(
            AIAnalyticsMetricEvidenceV1(
                identifier=identifier,
                value=metric.value,
                unit=metric.unit,
                event_ids=tuple(
                    sorted(
                        (
                            event_id
                            for event_id in metric.evidence.event_ids
                            if event_id in event_ids
                        ),
                        key=str,
                    )
                ),
                relationship_ids=tuple(
                    sorted(
                        (
                            relationship_id
                            for relationship_id in metric.evidence.relationship_ids
                            if relationship_id in relationship_ids
                        ),
                        key=str,
                    )
                ),
                quality=metric.quality,
            )
            for identifier in sorted(requirements.required_metric_identifiers)
            if (metric := metrics_by_identifier.get(identifier)) is not None
        )
        return AIEvidencePackageV1(
            context=AIConversationContextV1(
                events=events,
                relationships=relationships,
                source_event_schema_version=sequence.schema_version,
            ),
            analytics=metric_evidence,
            analytics_schema_version=analytics.schema_version,
            analytics_calculation_version=analytics.calculation_version,
        )
