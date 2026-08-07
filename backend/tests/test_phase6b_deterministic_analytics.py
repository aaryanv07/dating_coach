"""Phase 6B deterministic analytics tests using synthetic event timelines only."""

from dataclasses import FrozenInstanceError, fields
from datetime import UTC, datetime, timedelta
from uuid import UUID

import pytest

from app.domain.conversation_analytics import (
    ANALYTICS_CALCULATION_VERSION,
    ANALYTICS_SCHEMA_VERSION,
    AnalyticsInputV1,
    AnalyticsResultV1,
    AnalyticsReviewStatus,
    DeterministicConfidence,
    MetricV1,
    MissingDataReason,
    ReactionTypeCountV1,
    TimelineGapV1,
)
from app.domain.conversation_analytics_engine import (
    METRIC_DEFINITIONS,
    DeterministicConversationAnalyticsEngine,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventRelationship,
    ConfirmedConversationEventSequence,
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
    JsonObject,
)

BASE_TIME = datetime(2026, 7, 22, 9, 0, tzinfo=UTC)


def _uuid(value: int) -> UUID:
    return UUID(f"00000000-0000-4000-8000-{value:012d}")


def _event(
    value: int,
    position: int,
    event_type: ConversationEventType,
    speaker: ConversationEventSpeaker,
    *,
    text: str | None = None,
    minutes: int | None = None,
    timestamp_is_estimated: bool = False,
    requires_review: bool = False,
    metadata: JsonObject | None = None,
    deleted_at: datetime | None = None,
) -> ConfirmedConversationEvent:
    timestamp = BASE_TIME + timedelta(minutes=minutes) if minutes is not None else None
    return ConfirmedConversationEvent(
        id=_uuid(value),
        position=position,
        event_type=event_type,
        speaker=speaker,
        text=text,
        timestamp=timestamp,
        timestamp_is_estimated=timestamp_is_estimated,
        raw_timestamp_text=f"synthetic-{minutes}" if minutes is not None else None,
        source_image_index=0,
        source_region_id=f"synthetic-region-{value}",
        ocr_confidence=0.98,
        classification_confidence=0.97,
        speaker_confidence=0.99,
        timestamp_confidence=0.96 if minutes is not None else None,
        relationship_confidence=None,
        requires_review=requires_review,
        metadata=metadata or {},
        deleted_at=deleted_at,
    )


def _relationship(
    value: int,
    source: int,
    target: int,
    relationship_type: ConversationEventRelationshipType,
) -> ConfirmedConversationEventRelationship:
    return ConfirmedConversationEventRelationship(
        id=_uuid(value),
        source_event_id=_uuid(source),
        target_event_id=_uuid(target),
        relationship_type=relationship_type,
        confidence=0.95,
        metadata={},
    )


def _input(
    events: tuple[ConfirmedConversationEvent, ...],
    relationships: tuple[ConfirmedConversationEventRelationship, ...] = (),
    *,
    review_status: AnalyticsReviewStatus = AnalyticsReviewStatus.CONFIRMED,
    gaps: tuple[TimelineGapV1, ...] = (),
    partial: bool = False,
    event_schema_version: str = "conversation-events.v1",
) -> AnalyticsInputV1:
    return AnalyticsInputV1(
        event_sequence=ConfirmedConversationEventSequence(
            schema_version=event_schema_version,
            events=events,
            relationships=relationships,
        ),
        review_status=review_status,
        timeline_gaps=gaps,
        is_partial=partial,
    )


def _metric(result: AnalyticsResultV1, identifier: str) -> MetricV1:
    return next(
        metric for metric in result.all_metrics if metric.definition.identifier == identifier
    )


def _complete_timeline() -> AnalyticsInputV1:
    events = (
        _event(
            1,
            0,
            ConversationEventType.DATE_SEPARATOR,
            ConversationEventSpeaker.SYSTEM,
            text="Synthetic day",
        ),
        _event(
            2,
            1,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic plans?",
            minutes=0,
        ),
        _event(
            3,
            2,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic coffee statement.",
            minutes=2,
        ),
        _event(
            4,
            3,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Synthetic acknowledgement.",
            minutes=5,
        ),
        _event(
            5,
            4,
            ConversationEventType.REACTION,
            ConversationEventSpeaker.OTHER,
            metadata={"reaction": "heart"},
        ),
        _event(
            6,
            5,
            ConversationEventType.IMAGE,
            ConversationEventSpeaker.USER,
            minutes=10,
            metadata={"caption": "private synthetic caption"},
        ),
        _event(
            7,
            6,
            ConversationEventType.VOICE_NOTE,
            ConversationEventSpeaker.OTHER,
            minutes=15,
            metadata={"duration_seconds": 12},
        ),
        _event(
            8,
            7,
            ConversationEventType.REPLY_REFERENCE,
            ConversationEventSpeaker.OTHER,
        ),
        _event(
            9,
            8,
            ConversationEventType.DELETED_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text=None,
        ),
        _event(
            10,
            9,
            ConversationEventType.EDITED_MESSAGE_MARKER,
            ConversationEventSpeaker.USER,
        ),
        _event(
            11,
            10,
            ConversationEventType.LINK,
            ConversationEventSpeaker.USER,
            minutes=60,
        ),
        _event(
            12,
            11,
            ConversationEventType.LOCATION,
            ConversationEventSpeaker.OTHER,
            minutes=70,
        ),
        _event(
            13,
            12,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Synthetic duplicate that must not count.",
            minutes=71,
        ),
    )
    relationships = (
        _relationship(101, 5, 2, ConversationEventRelationshipType.REACTION_TARGET),
        _relationship(102, 8, 2, ConversationEventRelationshipType.REPLY_TARGET),
        _relationship(103, 13, 12, ConversationEventRelationshipType.DUPLICATE_OF),
    )
    return _input(events, relationships)


def test_complete_timeline_calculates_the_canonical_metric_catalog() -> None:
    result = DeterministicConversationAnalyticsEngine().analyze(_complete_timeline())

    expected_values: dict[str, int | float | UUID] = {
        "conversation.total_communication_events": 7,
        "conversation.total_user_events": 4,
        "conversation.total_other_events": 3,
        "conversation.duration_seconds": 4200.0,
        "conversation.active_duration_seconds": 1500.0,
        "conversation.inactive_duration_seconds": 2700.0,
        "conversation.first_event_id": _uuid(2),
        "conversation.last_event_id": _uuid(12),
        "participation.conversation_starts": 2,
        "messages.total": 7,
        "messages.text": 3,
        "messages.emoji": 0,
        "messages.media": 2,
        "messages.attachments": 3,
        "messages.deleted_markers": 1,
        "messages.edited_markers": 1,
        "participant.user.communication_events": 4,
        "participant.user.participation_share_percent": 57.142857,
        "participant.user.initiations": 2,
        "participant.user.consecutive_runs": 3,
        "participant.other.communication_events": 3,
        "participant.other.participation_share_percent": 42.857143,
        "participant.other.initiations": 0,
        "participant.other.consecutive_runs": 3,
        "timing.response_latency_mean_seconds": 816.0,
        "timing.response_latency_median_seconds": 300.0,
        "timing.response_latency_minimum_seconds": 180.0,
        "timing.response_latency_maximum_seconds": 2700.0,
        "timing.unanswered_question_duration_seconds": 0.0,
        "questions.total": 1,
        "questions.answered": 1,
        "questions.unanswered": 0,
        "replies.explicit": 1,
        "replies.orphan": 0,
        "reactions.sent_by_user": 0,
        "reactions.sent_by_other": 1,
        "reactions.received_by_user": 1,
        "reactions.received_by_other": 0,
        "reactions.targets": 1,
        "media.images": 1,
        "media.videos": 0,
        "media.voice_notes": 1,
        "media.documents": 0,
        "media.links": 1,
        "media.locations": 1,
        "structure.timeline_gaps": 0,
        "structure.duplicates": 1,
        "structure.unknown_events": 0,
        "structure.structural_events": 1,
    }
    for identifier, expected in expected_values.items():
        metric = _metric(result, identifier)
        assert metric.value == expected, identifier
        assert metric.quality.supported
        assert metric.quality.confidence == DeterministicConfidence.COMPLETE

    by_type = _metric(result, "reactions.by_type")
    assert isinstance(by_type.value, tuple)
    assert len(by_type.value) == 1
    reaction_count = by_type.value[0]
    assert isinstance(reaction_count, ReactionTypeCountV1)
    assert reaction_count.reaction_type == "heart"
    assert reaction_count.count == 1
    assert result.quality.supported
    assert set(METRIC_DEFINITIONS) == {
        metric.definition.identifier for metric in result.all_metrics
    }


def test_definitions_are_complete_versioned_and_partition_event_types() -> None:
    result = DeterministicConversationAnalyticsEngine().analyze(_complete_timeline())
    all_event_types = set(ConversationEventType)

    assert result.schema_version == ANALYTICS_SCHEMA_VERSION
    assert result.calculation_version == ANALYTICS_CALCULATION_VERSION
    for metric in result.all_metrics:
        definition = metric.definition
        assert definition.identifier
        assert definition.description
        assert definition.formula
        assert definition.required_fields
        assert set(definition.included_event_types).isdisjoint(definition.excluded_event_types)
        assert (
            set(definition.included_event_types) | set(definition.excluded_event_types)
            == all_event_types
        )
        assert metric.evidence.calculation_version == ANALYTICS_CALCULATION_VERSION


def test_timeline_gaps_are_visible_and_block_timing_and_participation() -> None:
    payload = _complete_timeline()
    gap_payload = _input(
        payload.event_sequence.events,
        payload.event_sequence.relationships,
        gaps=(TimelineGapV1(before_event_id=_uuid(7), after_event_id=_uuid(11)),),
    )

    result = DeterministicConversationAnalyticsEngine().analyze(gap_payload)

    gap_metric = _metric(result, "structure.timeline_gaps")
    assert gap_metric.value == 1
    assert gap_metric.quality.supported
    assert gap_metric.evidence.event_ids == (_uuid(7), _uuid(11))
    for identifier in (
        "conversation.duration_seconds",
        "participant.user.participation_share_percent",
        "timing.response_latency_median_seconds",
    ):
        metric = _metric(result, identifier)
        assert metric.value is None
        assert metric.quality.unsupported
        assert MissingDataReason.INCOMPLETE_TIMELINE in metric.quality.missing_data
    observed_media = _metric(result, "media.images")
    assert observed_media.value == 1
    assert observed_media.quality.confidence == DeterministicConfidence.REDUCED


def test_missing_and_estimated_timestamps_never_produce_timing_values() -> None:
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic one",
            minutes=0,
        ),
        _event(
            2,
            1,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Synthetic two",
            minutes=None,
        ),
        _event(
            3,
            2,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic three",
            minutes=4,
            timestamp_is_estimated=True,
        ),
    )

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events))

    for identifier in (
        "conversation.duration_seconds",
        "conversation.active_duration_seconds",
        "timing.response_latency_mean_seconds",
        "timing.unanswered_question_duration_seconds",
    ):
        metric = _metric(result, identifier)
        assert metric.value is None
        assert MissingDataReason.MISSING_TIMESTAMP in metric.quality.missing_data
        assert MissingDataReason.ESTIMATED_TIMESTAMP in metric.quality.missing_data


def test_missing_participant_blocks_participation_without_fabricating_speaker() -> None:
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.UNKNOWN,
            text="Synthetic unresolved speaker",
            minutes=0,
        ),
    )

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events))

    total = _metric(result, "messages.total")
    user = _metric(result, "conversation.total_user_events")
    assert total.value == 1
    assert user.value is None
    assert MissingDataReason.MISSING_PARTICIPANT in user.quality.missing_data


def test_pending_unknown_rejected_and_partial_events_are_never_silently_counted() -> None:
    rejected_at = BASE_TIME + timedelta(hours=1)
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Accepted synthetic event",
            minutes=0,
        ),
        _event(
            2,
            1,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Pending synthetic event",
            minutes=1,
            requires_review=True,
        ),
        _event(
            3,
            2,
            ConversationEventType.UNKNOWN,
            ConversationEventSpeaker.UNKNOWN,
            text="Unknown synthetic event",
            requires_review=True,
        ),
        _event(
            4,
            3,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Rejected synthetic event",
            minutes=2,
            deleted_at=rejected_at,
        ),
    )

    pending_result = DeterministicConversationAnalyticsEngine().analyze(_input(events))
    total = _metric(pending_result, "messages.total")
    assert total.value is None
    assert MissingDataReason.INCOMPLETE_REVIEW in total.quality.missing_data
    assert _metric(pending_result, "structure.unknown_events").value == 1

    partial_events = (events[0],)
    partial_result = DeterministicConversationAnalyticsEngine().analyze(
        _input(partial_events, partial=True)
    )
    partial_total = _metric(partial_result, "messages.total")
    assert partial_total.value is None
    assert MissingDataReason.PARTIAL_CONVERSATION in partial_total.quality.missing_data


def test_duplicate_reaction_deleted_unknown_and_relationship_boundaries() -> None:
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic target",
            minutes=0,
        ),
        _event(
            2,
            1,
            ConversationEventType.REACTION,
            ConversationEventSpeaker.OTHER,
            metadata={"reaction": "acknowledgement"},
        ),
        _event(
            3,
            2,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Synthetic duplicate",
            minutes=1,
        ),
        _event(
            4,
            3,
            ConversationEventType.DELETED_MESSAGE,
            ConversationEventSpeaker.OTHER,
        ),
    )
    relationships = (
        _relationship(101, 2, 1, ConversationEventRelationshipType.REACTION_TARGET),
        _relationship(102, 3, 1, ConversationEventRelationshipType.DUPLICATE_OF),
    )

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events, relationships))

    assert _metric(result, "messages.total").value == 1
    assert _metric(result, "messages.deleted_markers").value == 1
    assert _metric(result, "structure.duplicates").value == 1
    assert _metric(result, "reactions.sent_by_other").value == 1
    received = _metric(result, "reactions.received_by_user")
    assert received.value == 1
    assert received.evidence.event_ids == (_uuid(2), _uuid(1))
    assert received.evidence.relationship_ids == (_uuid(101),)
    assert _metric(result, "reactions.targets").value == 1

    invalid = _relationship(103, 1, 2, ConversationEventRelationshipType.REACTION_TARGET)
    invalid_result = DeterministicConversationAnalyticsEngine().analyze(
        _input(events, (*relationships, invalid))
    )
    received = _metric(invalid_result, "reactions.received_by_user")
    assert received.value is None
    assert MissingDataReason.UNRESOLVED_RELATIONSHIP in received.quality.missing_data


def test_explicit_and_orphan_reply_handling_is_structural_only() -> None:
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="First synthetic question?",
            minutes=0,
        ),
        _event(
            2,
            1,
            ConversationEventType.REPLY_REFERENCE,
            ConversationEventSpeaker.OTHER,
        ),
        _event(
            3,
            2,
            ConversationEventType.REPLY_REFERENCE,
            ConversationEventSpeaker.USER,
        ),
        _event(
            4,
            3,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
            text="Second synthetic question?",
            minutes=10,
        ),
    )
    relationships = (_relationship(101, 2, 1, ConversationEventRelationshipType.REPLY_TARGET),)

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events, relationships))

    assert _metric(result, "questions.total").value == 2
    assert _metric(result, "questions.answered").value == 1
    assert _metric(result, "questions.unanswered").value == 1
    assert _metric(result, "replies.explicit").value == 1
    assert _metric(result, "replies.orphan").value == 1
    assert _metric(result, "timing.unanswered_question_duration_seconds").value == 0.0
    answered = _metric(result, "questions.answered")
    assert answered.evidence.event_ids == (_uuid(1), _uuid(2))
    assert answered.evidence.relationship_ids == (_uuid(101),)


def test_identical_inputs_are_equal_and_output_contracts_are_immutable() -> None:
    engine = DeterministicConversationAnalyticsEngine()
    payload = _complete_timeline()

    first = engine.analyze(payload)
    second = engine.analyze(payload)

    assert first == second
    with pytest.raises(FrozenInstanceError):
        first.schema_version = "conversation-analytics.v2"  # type: ignore[assignment,misc]
    with pytest.raises(FrozenInstanceError):
        first.quality.supported = False  # type: ignore[misc]
    assert {field.name for field in fields(type(first))} >= {
        "schema_version",
        "source_schema_version",
        "calculation_version",
        "quality",
    }
    assert all(metric.schema_version.endswith(".v1") for metric in first.all_metrics)
    assert all(
        section.schema_version.endswith(".v1")
        for section in (
            first.conversation,
            first.messages,
            *first.participants,
            first.timeline,
            first.questions,
            first.replies,
            first.reactions,
            first.media,
            first.structure,
        )
    )


def test_unsupported_source_version_is_rejected_without_guessing() -> None:
    with pytest.raises(ValueError, match="unsupported conversation-event schema version"):
        _input(_complete_timeline().event_sequence.events, event_schema_version="events.v2")

    with pytest.raises(ValueError, match="timeline gaps must reference events"):
        _input(
            _complete_timeline().event_sequence.events,
            gaps=(TimelineGapV1(before_event_id=_uuid(999)),),
        )


def test_relationship_to_rejected_target_is_explicitly_unsupported() -> None:
    events = (
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
            text="Rejected synthetic target",
            minutes=0,
            deleted_at=BASE_TIME + timedelta(minutes=2),
        ),
        _event(
            2,
            1,
            ConversationEventType.REACTION,
            ConversationEventSpeaker.OTHER,
            metadata={"reaction": "synthetic"},
        ),
    )
    relationships = (_relationship(101, 2, 1, ConversationEventRelationshipType.REACTION_TARGET),)

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events, relationships))

    received = _metric(result, "reactions.received_by_user")
    assert received.value is None
    assert MissingDataReason.UNRESOLVED_RELATIONSHIP in received.quality.missing_data


def test_evidence_and_engine_diagnostics_remain_content_free(
    caplog: pytest.LogCaptureFixture,
) -> None:
    caplog.clear()
    result = DeterministicConversationAnalyticsEngine().analyze(_complete_timeline())

    assert caplog.records == []
    representation = repr(result)
    assert "Synthetic plans?" not in representation
    assert "private synthetic caption" not in representation
    for metric in result.all_metrics:
        assert all(isinstance(event_id, UUID) for event_id in metric.evidence.event_ids)
        assert all(
            isinstance(relationship_id, UUID)
            for relationship_id in metric.evidence.relationship_ids
        )


def test_large_synthetic_timeline_remains_deterministic_without_extra_metrics() -> None:
    events = tuple(
        _event(
            value=index + 1,
            position=index,
            event_type=ConversationEventType.TEXT_MESSAGE,
            speaker=(
                ConversationEventSpeaker.USER if index % 2 == 0 else ConversationEventSpeaker.OTHER
            ),
            text="Synthetic benchmark statement.",
            minutes=index,
        )
        for index in range(5000)
    )

    result = DeterministicConversationAnalyticsEngine().analyze(_input(events))

    assert _metric(result, "messages.total").value == 5000
    assert len(result.all_metrics) == len(METRIC_DEFINITIONS)
