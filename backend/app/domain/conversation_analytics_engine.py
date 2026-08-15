"""Pure deterministic analytics over reviewed canonical conversation events."""

from dataclasses import dataclass
from datetime import datetime
from itertools import pairwise
from statistics import median
from uuid import UUID

from app.domain.conversation_analytics import (
    AnalyticsInputV1,
    AnalyticsResultV1,
    AnalyticsReviewStatus,
    ConversationAnalyticsV1,
    DeterministicConfidence,
    EvidenceReferenceV1,
    MediaAnalyticsV1,
    MessageAnalyticsV1,
    MetricDefinitionV1,
    MetricUnit,
    MetricV1,
    MissingDataReason,
    ParticipantAnalyticsV1,
    QualityMetadataV1,
    QuestionAnalyticsV1,
    ReactionAnalyticsV1,
    ReactionTypeCountV1,
    ReplyAnalyticsV1,
    StructureAnalyticsV1,
    TimelineAnalyticsV1,
)
from app.domain.conversation_events import (
    PARTICIPANT_EVENT_TYPES,
    SYSTEM_EVENT_TYPES,
    ConfirmedConversationEvent,
    ConfirmedConversationEventRelationship,
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
)

ACTIVE_INTERVAL_SECONDS = 30 * 60

MEDIA_EVENT_TYPES = frozenset(
    {
        ConversationEventType.IMAGE,
        ConversationEventType.VIDEO,
        ConversationEventType.GIF,
        ConversationEventType.STICKER,
        ConversationEventType.VOICE_NOTE,
        ConversationEventType.AUDIO,
    }
)

ATTACHMENT_EVENT_TYPES = frozenset(
    {
        *MEDIA_EVENT_TYPES,
        ConversationEventType.DOCUMENT,
        ConversationEventType.CONTACT_CARD,
        ConversationEventType.LOCATION,
        ConversationEventType.POLL,
        ConversationEventType.PAYMENT_REQUEST,
    }
)

CALL_EVENT_TYPES = frozenset(
    {
        ConversationEventType.CALL_STARTED,
        ConversationEventType.CALL_ENDED,
        ConversationEventType.MISSED_CALL,
        ConversationEventType.DECLINED_CALL,
    }
)

STRUCTURAL_COUNT_EVENT_TYPES = frozenset({*SYSTEM_EVENT_TYPES, *CALL_EVENT_TYPES})
ALL_EVENT_TYPES = tuple(ConversationEventType)


def _definition(
    identifier: str,
    description: str,
    formula: str,
    *,
    included: frozenset[ConversationEventType],
    required: tuple[str, ...] = (),
    unsupported: tuple[MissingDataReason, ...] = (),
) -> MetricDefinitionV1:
    return MetricDefinitionV1(
        identifier=identifier,
        description=description,
        formula=formula,
        included_event_types=tuple(event for event in ALL_EVENT_TYPES if event in included),
        excluded_event_types=tuple(event for event in ALL_EVENT_TYPES if event not in included),
        required_fields=required,
        unsupported_conditions=unsupported,
    )


_REVIEW_OR_PARTIAL = (
    MissingDataReason.INCOMPLETE_REVIEW,
    MissingDataReason.PARTIAL_CONVERSATION,
)
_PARTICIPATION_UNSUPPORTED = (
    *_REVIEW_OR_PARTIAL,
    MissingDataReason.MISSING_PARTICIPANT,
    MissingDataReason.UNKNOWN_EVENT,
    MissingDataReason.INCOMPLETE_TIMELINE,
)
_TIMING_UNSUPPORTED = (
    *_PARTICIPATION_UNSUPPORTED,
    MissingDataReason.MISSING_TIMESTAMP,
    MissingDataReason.ESTIMATED_TIMESTAMP,
    MissingDataReason.INSUFFICIENT_EVIDENCE,
)
_RELATIONSHIP_UNSUPPORTED = (
    *_REVIEW_OR_PARTIAL,
    MissingDataReason.UNRESOLVED_RELATIONSHIP,
)

METRIC_DEFINITIONS = {
    definition.identifier: definition
    for definition in (
        _definition(
            "conversation.total_communication_events",
            "Accepted non-duplicate participant communication events in the reviewed timeline.",
            "Count accepted events whose type is in the participant communication set.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("event_type", "requires_review", "deleted_at"),
            unsupported=(*_REVIEW_OR_PARTIAL, MissingDataReason.UNKNOWN_EVENT),
        ),
        _definition(
            "conversation.total_user_events",
            "Accepted communication events attributed to the user.",
            "Count accepted communication events with speaker=user.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("event_type", "speaker"),
            unsupported=_PARTICIPATION_UNSUPPORTED,
        ),
        _definition(
            "conversation.total_other_events",
            "Accepted communication events attributed to the other participant.",
            "Count accepted communication events with speaker=other.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("event_type", "speaker"),
            unsupported=_PARTICIPATION_UNSUPPORTED,
        ),
        _definition(
            "conversation.duration_seconds",
            "Elapsed seconds between the first and last accepted communication events.",
            "last exact canonical timestamp minus first exact canonical timestamp.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("timestamp", "timestamp_is_estimated", "position"),
            unsupported=_TIMING_UNSUPPORTED,
        ),
        _definition(
            "conversation.active_duration_seconds",
            "Sum of adjacent communication intervals no longer than 30 minutes.",
            "Sum max(0, next_timestamp-current_timestamp) for intervals <= 1800 seconds.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("timestamp", "timestamp_is_estimated", "position"),
            unsupported=_TIMING_UNSUPPORTED,
        ),
        _definition(
            "conversation.inactive_duration_seconds",
            "Sum of adjacent communication intervals longer than 30 minutes.",
            "Sum next_timestamp-current_timestamp for intervals > 1800 seconds.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("timestamp", "timestamp_is_estimated", "position"),
            unsupported=_TIMING_UNSUPPORTED,
        ),
        _definition(
            "conversation.first_event_id",
            "Identifier of the first accepted communication event by canonical position.",
            "Event ID at the minimum accepted communication-event position.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("id", "position"),
            unsupported=(*_REVIEW_OR_PARTIAL, MissingDataReason.INSUFFICIENT_EVIDENCE),
        ),
        _definition(
            "conversation.last_event_id",
            "Identifier of the last accepted communication event by canonical position.",
            "Event ID at the maximum accepted communication-event position.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("id", "position"),
            unsupported=(*_REVIEW_OR_PARTIAL, MissingDataReason.INSUFFICIENT_EVIDENCE),
        ),
        _definition(
            "participation.conversation_starts",
            "Observed timeline sessions using a fixed 30-minute inactivity boundary.",
            "One for a non-empty timeline plus each adjacent exact interval over 1800 seconds.",
            included=PARTICIPANT_EVENT_TYPES,
            required=("timestamp", "timestamp_is_estimated", "position"),
            unsupported=_TIMING_UNSUPPORTED,
        ),
        *(
            _definition(
                f"messages.{identifier}",
                description,
                formula,
                included=included,
                required=("event_type",),
                unsupported=_REVIEW_OR_PARTIAL,
            )
            for identifier, description, formula, included in (
                (
                    "total",
                    "Accepted non-duplicate participant contribution events.",
                    "Count accepted events in the participant communication set.",
                    PARTICIPANT_EVENT_TYPES,
                ),
                (
                    "text",
                    "Accepted text-message events.",
                    "Count accepted text_message events.",
                    frozenset({ConversationEventType.TEXT_MESSAGE}),
                ),
                (
                    "emoji",
                    "Accepted standalone emoji-message events.",
                    "Count accepted emoji_message events; attached reactions are excluded.",
                    frozenset({ConversationEventType.EMOJI_MESSAGE}),
                ),
                (
                    "media",
                    "Accepted visual or audio media contribution events.",
                    "Count accepted image, video, gif, sticker, voice_note, and audio events.",
                    MEDIA_EVENT_TYPES,
                ),
                (
                    "attachments",
                    "Accepted attachment-style participant contribution events.",
                    "Count accepted media, document, contact_card, location, poll, and "
                    "payment_request events.",
                    ATTACHMENT_EVENT_TYPES,
                ),
                (
                    "deleted_markers",
                    "Visible deleted-message markers without reconstructed content.",
                    "Count accepted deleted_message marker events.",
                    frozenset({ConversationEventType.DELETED_MESSAGE}),
                ),
                (
                    "edited_markers",
                    "Visible edited-message markers.",
                    "Count accepted edited_message_marker events.",
                    frozenset({ConversationEventType.EDITED_MESSAGE_MARKER}),
                ),
            )
        ),
        *(
            _definition(
                f"participant.{speaker.value}.{identifier}",
                description.format(speaker=speaker.value),
                formula.format(speaker=speaker.value),
                included=PARTICIPANT_EVENT_TYPES,
                required=required,
                unsupported=unsupported,
            )
            for speaker in (
                ConversationEventSpeaker.USER,
                ConversationEventSpeaker.OTHER,
            )
            for identifier, description, formula, required, unsupported in (
                (
                    "communication_events",
                    "Accepted communication events attributed to {speaker}.",
                    "Count accepted communication events with speaker={speaker}.",
                    ("speaker", "event_type"),
                    _PARTICIPATION_UNSUPPORTED,
                ),
                (
                    "participation_share_percent",
                    "Observed event share for {speaker}; this is not a relationship score.",
                    "100 * {speaker} accepted communication events / all accepted "
                    "communication events.",
                    ("speaker", "event_type"),
                    (*_PARTICIPATION_UNSUPPORTED, MissingDataReason.INSUFFICIENT_EVIDENCE),
                ),
                (
                    "initiations",
                    "Timeline sessions whose first accepted event is from {speaker}.",
                    "Count session starts attributed to {speaker} using the fixed "
                    "30-minute boundary.",
                    ("speaker", "timestamp", "timestamp_is_estimated", "position"),
                    _TIMING_UNSUPPORTED,
                ),
                (
                    "consecutive_runs",
                    "Contiguous same-speaker communication runs attributed to {speaker}.",
                    "Count maximal contiguous accepted communication-event runs for {speaker}.",
                    ("speaker", "position"),
                    _PARTICIPATION_UNSUPPORTED,
                ),
            )
        ),
        *(
            _definition(
                f"timing.{identifier}",
                description,
                formula,
                included=PARTICIPANT_EVENT_TYPES,
                required=("speaker", "timestamp", "timestamp_is_estimated", "position"),
                unsupported=_TIMING_UNSUPPORTED,
            )
            for identifier, description, formula in (
                (
                    "response_latency_mean_seconds",
                    "Mean exact delay at an adjacent participant-speaker change.",
                    "Arithmetic mean of non-negative adjacent exact timestamp gaps "
                    "where speaker changes.",
                ),
                (
                    "response_latency_median_seconds",
                    "Median exact delay at an adjacent participant-speaker change.",
                    "Median of non-negative adjacent exact timestamp gaps where speaker changes.",
                ),
                (
                    "response_latency_minimum_seconds",
                    "Minimum exact delay at an adjacent participant-speaker change.",
                    "Minimum non-negative adjacent exact timestamp gap where speaker changes.",
                ),
                (
                    "response_latency_maximum_seconds",
                    "Maximum exact delay at an adjacent participant-speaker change.",
                    "Maximum non-negative adjacent exact timestamp gap where speaker changes.",
                ),
                (
                    "unanswered_question_duration_seconds",
                    "Observed duration from the earliest explicitly unanswered question "
                    "to timeline end.",
                    "Last exact timeline timestamp minus the earliest question without "
                    "an explicit reply_target; zero when none.",
                ),
            )
        ),
        *(
            _definition(
                f"questions.{identifier}",
                description,
                formula,
                included=frozenset(
                    {
                        ConversationEventType.TEXT_MESSAGE,
                        ConversationEventType.REPLY_REFERENCE,
                    }
                ),
                required=("event_type", "text", "relationship_type"),
                unsupported=unsupported,
            )
            for identifier, description, formula, unsupported in (
                (
                    "total",
                    "Accepted text messages containing at least one literal question mark.",
                    "Count accepted text_message events whose visible text contains '?'.",
                    _REVIEW_OR_PARTIAL,
                ),
                (
                    "answered",
                    "Question events targeted by at least one valid explicit reply relationship.",
                    "Count unique question event IDs targeted by a valid reply_target "
                    "relationship.",
                    (*_RELATIONSHIP_UNSUPPORTED, MissingDataReason.UNKNOWN_EVENT),
                ),
                (
                    "unanswered",
                    "Question events without a valid explicit reply relationship.",
                    "total question event IDs minus unique answered question event IDs.",
                    (*_RELATIONSHIP_UNSUPPORTED, MissingDataReason.UNKNOWN_EVENT),
                ),
            )
        ),
        *(
            _definition(
                f"replies.{identifier}",
                description,
                formula,
                included=frozenset({ConversationEventType.REPLY_REFERENCE}),
                required=("event_type", "relationship_type", "source_event_id", "target_event_id"),
                unsupported=_RELATIONSHIP_UNSUPPORTED,
            )
            for identifier, description, formula in (
                (
                    "explicit",
                    "Accepted reply-reference events with a valid reply target.",
                    "Count unique accepted reply_reference sources in valid reply_target "
                    "relationships.",
                ),
                (
                    "orphan",
                    "Accepted reply-reference events without a valid reply target.",
                    "Accepted reply_reference event count minus valid explicit reply source count.",
                ),
            )
        ),
        *(
            _definition(
                f"reactions.{identifier}",
                description,
                formula,
                included=frozenset({ConversationEventType.REACTION}),
                required=required,
                unsupported=unsupported,
            )
            for identifier, description, formula, required, unsupported in (
                (
                    "sent_by_user",
                    "Accepted reactions attributed to the user.",
                    "Count accepted non-duplicate reaction events with speaker=user.",
                    ("speaker", "event_type"),
                    (*_REVIEW_OR_PARTIAL, MissingDataReason.MISSING_PARTICIPANT),
                ),
                (
                    "sent_by_other",
                    "Accepted reactions attributed to the other participant.",
                    "Count accepted non-duplicate reaction events with speaker=other.",
                    ("speaker", "event_type"),
                    (*_REVIEW_OR_PARTIAL, MissingDataReason.MISSING_PARTICIPANT),
                ),
                (
                    "received_by_user",
                    "Accepted reactions whose valid target is a user contribution.",
                    "Count valid reaction_target relationships whose target speaker=user.",
                    ("relationship_type", "target_event_id", "speaker"),
                    (*_RELATIONSHIP_UNSUPPORTED, MissingDataReason.MISSING_PARTICIPANT),
                ),
                (
                    "received_by_other",
                    "Accepted reactions whose valid target is an other-participant contribution.",
                    "Count valid reaction_target relationships whose target speaker=other.",
                    ("relationship_type", "target_event_id", "speaker"),
                    (*_RELATIONSHIP_UNSUPPORTED, MissingDataReason.MISSING_PARTICIPANT),
                ),
                (
                    "by_type",
                    "Accepted reaction counts grouped by the reviewed reaction metadata value.",
                    "Group accepted reaction events by string metadata.reaction; missing "
                    "values use unspecified.",
                    ("metadata.reaction",),
                    _REVIEW_OR_PARTIAL,
                ),
                (
                    "targets",
                    "Distinct accepted events targeted by valid reactions.",
                    "Count distinct target event IDs in valid reaction_target relationships.",
                    ("relationship_type", "target_event_id"),
                    _RELATIONSHIP_UNSUPPORTED,
                ),
            )
        ),
        *(
            _definition(
                f"media.{identifier}",
                description,
                f"Count accepted {event_type.value} events.",
                included=frozenset({event_type}),
                required=("event_type",),
                unsupported=_REVIEW_OR_PARTIAL,
            )
            for identifier, description, event_type in (
                ("images", "Accepted image contribution events.", ConversationEventType.IMAGE),
                ("videos", "Accepted video contribution events.", ConversationEventType.VIDEO),
                (
                    "voice_notes",
                    "Accepted voice-note contribution events without transcription.",
                    ConversationEventType.VOICE_NOTE,
                ),
                (
                    "documents",
                    "Accepted document contribution events without content inspection.",
                    ConversationEventType.DOCUMENT,
                ),
                (
                    "links",
                    "Accepted link contribution events without visiting them.",
                    ConversationEventType.LINK,
                ),
                (
                    "locations",
                    "Accepted location contribution events without precision inference.",
                    ConversationEventType.LOCATION,
                ),
            )
        ),
        *(
            _definition(
                f"structure.{identifier}",
                description,
                formula,
                included=included,
                required=required,
                unsupported=(),
            )
            for identifier, description, formula, included, required in (
                (
                    "timeline_gaps",
                    "Explicit reviewed missing-timeline intervals.",
                    "Count declared AnalyticsInputV1 timeline gaps.",
                    frozenset(),
                    ("timeline_gaps",),
                ),
                (
                    "duplicates",
                    "Active events excluded by a valid duplicate_of relationship.",
                    "Count distinct active source event IDs in valid duplicate_of relationships.",
                    frozenset(ConversationEventType),
                    ("relationship_type", "source_event_id", "target_event_id"),
                ),
                (
                    "unknown_events",
                    "Active canonical unknown events retained for review.",
                    "Count active events with event_type=unknown.",
                    frozenset({ConversationEventType.UNKNOWN}),
                    ("event_type",),
                ),
                (
                    "structural_events",
                    "Accepted system, separator, member, encryption, and call timeline events.",
                    "Count accepted events in the structural/context event set.",
                    STRUCTURAL_COUNT_EVENT_TYPES,
                    ("event_type",),
                ),
            )
        ),
    )
}


@dataclass(frozen=True, slots=True)
class _AnalysisContext:
    payload: AnalyticsInputV1
    active_events: tuple[ConfirmedConversationEvent, ...]
    accepted_events: tuple[ConfirmedConversationEvent, ...]
    communication_events: tuple[ConfirmedConversationEvent, ...]
    relationships: tuple[ConfirmedConversationEventRelationship, ...]
    duplicate_event_ids: frozenset[UUID]
    invalid_relationship_ids: frozenset[UUID]
    incomplete_review: bool
    partial: bool
    incomplete_timeline: bool
    unknown_events: tuple[ConfirmedConversationEvent, ...]
    missing_participant: bool
    missing_timestamp: bool
    estimated_timestamp: bool
    non_monotonic_timeline: bool


def _build_context(payload: AnalyticsInputV1) -> _AnalysisContext:
    events = tuple(sorted(payload.event_sequence.events, key=lambda event: event.position))
    event_ids = [event.id for event in events]
    positions = [event.position for event in events]
    if len(event_ids) != len(set(event_ids)):
        raise ValueError("canonical analytics input contains duplicate event IDs")
    if len(positions) != len(set(positions)):
        raise ValueError("canonical analytics input contains duplicate event positions")
    if positions != list(range(len(positions))):
        raise ValueError("canonical analytics input positions must be contiguous from zero")

    active = tuple(event for event in events if event.deleted_at is None)
    active_by_id = {event.id: event for event in active}
    all_by_id = {event.id: event for event in events}

    relationships = tuple(
        sorted(payload.event_sequence.relationships, key=lambda relationship: str(relationship.id))
    )
    relationship_ids = [relationship.id for relationship in relationships]
    if len(relationship_ids) != len(set(relationship_ids)):
        raise ValueError("canonical analytics input contains duplicate relationship IDs")

    expected_sources = {
        ConversationEventRelationshipType.REACTION_TARGET: ConversationEventType.REACTION,
        ConversationEventRelationshipType.REPLY_TARGET: ConversationEventType.REPLY_REFERENCE,
        ConversationEventRelationshipType.EDIT_TARGET: ConversationEventType.EDITED_MESSAGE_MARKER,
    }
    invalid_relationship_ids: set[UUID] = set()
    duplicate_event_ids: set[UUID] = set()
    for relationship in relationships:
        source = all_by_id.get(relationship.source_event_id)
        target = all_by_id.get(relationship.target_event_id)
        expected = expected_sources.get(relationship.relationship_type)
        if (
            source is None
            or target is None
            or (expected is not None and source.event_type != expected)
        ):
            invalid_relationship_ids.add(relationship.id)
            continue
        if source.id not in active_by_id:
            continue
        if (
            target.id not in active_by_id
            or target.requires_review
            or (target.event_type == ConversationEventType.UNKNOWN)
        ):
            invalid_relationship_ids.add(relationship.id)
            continue
        if relationship.relationship_type == ConversationEventRelationshipType.DUPLICATE_OF:
            duplicate_event_ids.add(source.id)

    pending = tuple(event for event in active if event.requires_review)
    unknown = tuple(event for event in active if event.event_type == ConversationEventType.UNKNOWN)
    accepted = tuple(
        event
        for event in active
        if not event.requires_review
        and event.event_type != ConversationEventType.UNKNOWN
        and event.id not in duplicate_event_ids
    )
    communication = tuple(
        event for event in accepted if event.event_type in PARTICIPANT_EVENT_TYPES
    )
    missing_participant = any(
        event.speaker not in {ConversationEventSpeaker.USER, ConversationEventSpeaker.OTHER}
        for event in communication
    )
    missing_timestamp = any(event.timestamp is None for event in communication)
    estimated_timestamp = any(event.timestamp_is_estimated for event in communication)
    exact_timestamps = [
        event.timestamp
        for event in communication
        if event.timestamp is not None and not event.timestamp_is_estimated
    ]
    non_monotonic = any(
        current is not None and following is not None and following < current
        for current, following in pairwise(exact_timestamps)
    )
    return _AnalysisContext(
        payload=payload,
        active_events=active,
        accepted_events=accepted,
        communication_events=communication,
        relationships=relationships,
        duplicate_event_ids=frozenset(duplicate_event_ids),
        invalid_relationship_ids=frozenset(invalid_relationship_ids),
        incomplete_review=(
            payload.review_status != AnalyticsReviewStatus.CONFIRMED or bool(pending)
        ),
        partial=payload.is_partial,
        incomplete_timeline=bool(payload.timeline_gaps),
        unknown_events=unknown,
        missing_participant=missing_participant,
        missing_timestamp=missing_timestamp,
        estimated_timestamp=estimated_timestamp,
        non_monotonic_timeline=non_monotonic,
    )


def _event_ids(events: tuple[ConfirmedConversationEvent, ...]) -> tuple[UUID, ...]:
    return tuple(dict.fromkeys(event.id for event in events))


def _relationship_ids(
    relationships: tuple[ConfirmedConversationEventRelationship, ...],
) -> tuple[UUID, ...]:
    return tuple(dict.fromkeys(relationship.id for relationship in relationships))


def _relationship_event_ids(
    relationships: tuple[ConfirmedConversationEventRelationship, ...],
) -> tuple[UUID, ...]:
    return tuple(
        dict.fromkeys(
            event_id
            for relationship in relationships
            for event_id in (relationship.source_event_id, relationship.target_event_id)
        )
    )


def _evidence(
    events: tuple[ConfirmedConversationEvent, ...] = (),
    relationships: tuple[ConfirmedConversationEventRelationship, ...] = (),
    extra_event_ids: tuple[UUID, ...] = (),
) -> EvidenceReferenceV1:
    return EvidenceReferenceV1(
        event_ids=tuple(dict.fromkeys((*_event_ids(events), *extra_event_ids))),
        relationship_ids=_relationship_ids(relationships),
    )


def _present_reasons(context: _AnalysisContext) -> set[MissingDataReason]:
    reasons: set[MissingDataReason] = set()
    if context.incomplete_review:
        reasons.add(MissingDataReason.INCOMPLETE_REVIEW)
    if context.partial:
        reasons.add(MissingDataReason.PARTIAL_CONVERSATION)
    if context.incomplete_timeline or context.non_monotonic_timeline:
        reasons.add(MissingDataReason.INCOMPLETE_TIMELINE)
    if context.unknown_events:
        reasons.add(MissingDataReason.UNKNOWN_EVENT)
    if context.missing_participant:
        reasons.add(MissingDataReason.MISSING_PARTICIPANT)
    if context.missing_timestamp:
        reasons.add(MissingDataReason.MISSING_TIMESTAMP)
    if context.estimated_timestamp:
        reasons.add(MissingDataReason.ESTIMATED_TIMESTAMP)
    if context.invalid_relationship_ids:
        reasons.add(MissingDataReason.UNRESOLVED_RELATIONSHIP)
    return reasons


def _quality(
    context: _AnalysisContext,
    *,
    hard: set[MissingDataReason] | None = None,
    soft: set[MissingDataReason] | None = None,
) -> QualityMetadataV1:
    hard = hard or set()
    soft = (soft or set()) - hard
    supported = not hard
    confidence = (
        DeterministicConfidence.UNAVAILABLE
        if hard
        else DeterministicConfidence.REDUCED
        if soft
        else DeterministicConfidence.COMPLETE
    )
    return QualityMetadataV1(
        supported=supported,
        unsupported=not supported,
        confidence=confidence,
        missing_data=tuple(sorted((*hard, *soft), key=lambda reason: reason.value)),
        review_status=(
            AnalyticsReviewStatus.INCOMPLETE_REVIEW
            if context.incomplete_review
            else AnalyticsReviewStatus.CONFIRMED
        ),
        incomplete_timeline=(context.incomplete_timeline or context.non_monotonic_timeline),
    )


def _metric(
    context: _AnalysisContext,
    identifier: str,
    value: int | float | UUID | tuple[ReactionTypeCountV1, ...],
    unit: MetricUnit,
    evidence: EvidenceReferenceV1,
    *,
    hard: set[MissingDataReason] | None = None,
    soft: set[MissingDataReason] | None = None,
) -> MetricV1:
    quality = _quality(context, hard=hard, soft=soft)
    return MetricV1(
        definition=METRIC_DEFINITIONS[identifier],
        value=value if quality.supported else None,
        unit=unit,
        evidence=evidence,
        quality=quality,
    )


def _base_hard(context: _AnalysisContext) -> set[MissingDataReason]:
    reasons = _present_reasons(context)
    return reasons & {
        MissingDataReason.INCOMPLETE_REVIEW,
        MissingDataReason.PARTIAL_CONVERSATION,
    }


def _observed_soft(context: _AnalysisContext) -> set[MissingDataReason]:
    reasons = _present_reasons(context)
    return reasons & {
        MissingDataReason.INCOMPLETE_TIMELINE,
        MissingDataReason.UNKNOWN_EVENT,
    }


def _participation_hard(context: _AnalysisContext) -> set[MissingDataReason]:
    reasons = _present_reasons(context)
    return reasons & set(_PARTICIPATION_UNSUPPORTED)


def _timing_hard(
    context: _AnalysisContext, *, insufficient: bool = False
) -> set[MissingDataReason]:
    reasons = _present_reasons(context) & set(_TIMING_UNSUPPORTED)
    if insufficient:
        reasons.add(MissingDataReason.INSUFFICIENT_EVIDENCE)
    return reasons


def _relationship_hard(context: _AnalysisContext) -> set[MissingDataReason]:
    reasons = _present_reasons(context)
    return reasons & set(_RELATIONSHIP_UNSUPPORTED)


def _exact_seconds(earlier: datetime, later: datetime) -> float:
    return max(0.0, (later - earlier).total_seconds())


def _metric_for_type(
    context: _AnalysisContext,
    identifier: str,
    event_types: frozenset[ConversationEventType],
) -> MetricV1:
    events = tuple(event for event in context.accepted_events if event.event_type in event_types)
    return _metric(
        context,
        identifier,
        len(events),
        MetricUnit.COUNT,
        _evidence(events),
        hard=_base_hard(context),
        soft=_observed_soft(context),
    )


class DeterministicConversationAnalyticsEngine:
    """Calculate the Phase 6B catalog without I/O, persistence, or inference."""

    def analyze(self, payload: AnalyticsInputV1) -> AnalyticsResultV1:
        context = _build_context(payload)
        conversation, participants, timeline = self._conversation_participation_timing(context)
        questions, replies, unanswered_metric = self._questions_and_replies(context)
        timeline = TimelineAnalyticsV1(metrics=(*timeline.metrics, unanswered_metric))
        reactions = self._reactions(context)
        result = AnalyticsResultV1(
            conversation=conversation,
            messages=self._messages(context),
            participants=participants,
            timeline=timeline,
            questions=questions,
            replies=replies,
            reactions=reactions,
            media=self._media(context),
            structure=self._structure(context),
            quality=self._overall_quality(context),
        )
        if len({metric.definition.identifier for metric in result.all_metrics}) != len(
            result.all_metrics
        ):
            raise RuntimeError("analytics metric identifiers must be unique")
        return result

    def _conversation_participation_timing(
        self, context: _AnalysisContext
    ) -> tuple[
        ConversationAnalyticsV1,
        tuple[ParticipantAnalyticsV1, ParticipantAnalyticsV1],
        TimelineAnalyticsV1,
    ]:
        events = context.communication_events
        participant_events = {
            speaker: tuple(event for event in events if event.speaker == speaker)
            for speaker in (
                ConversationEventSpeaker.USER,
                ConversationEventSpeaker.OTHER,
            )
        }
        exact_timeline = bool(events) and not _timing_hard(context)
        intervals: list[float] = []
        if exact_timeline:
            intervals = [
                _exact_seconds(current.timestamp, following.timestamp)
                for current, following in pairwise(events)
                if current.timestamp is not None and following.timestamp is not None
            ]
        duration = sum(intervals)
        active_duration = sum(
            interval for interval in intervals if interval <= ACTIVE_INTERVAL_SECONDS
        )
        inactive_duration = sum(
            interval for interval in intervals if interval > ACTIVE_INTERVAL_SECONDS
        )
        session_start_indexes = (
            [0]
            + [
                index + 1
                for index, interval in enumerate(intervals)
                if interval > ACTIVE_INTERVAL_SECONDS
            ]
            if events
            else []
        )
        session_start_events = tuple(events[index] for index in session_start_indexes)

        response_pairs = tuple(
            (current, following)
            for current, following in pairwise(events)
            if current.speaker != following.speaker
            and current.speaker in {ConversationEventSpeaker.USER, ConversationEventSpeaker.OTHER}
            and following.speaker in {ConversationEventSpeaker.USER, ConversationEventSpeaker.OTHER}
        )
        response_latencies = [
            _exact_seconds(current.timestamp, following.timestamp)
            for current, following in response_pairs
            if current.timestamp is not None and following.timestamp is not None
        ]
        response_events = tuple(event for pair in response_pairs for event in pair)

        run_speakers: list[ConversationEventSpeaker] = []
        run_events: dict[ConversationEventSpeaker, list[ConfirmedConversationEvent]] = {
            ConversationEventSpeaker.USER: [],
            ConversationEventSpeaker.OTHER: [],
        }
        previous_speaker: ConversationEventSpeaker | None = None
        for event in events:
            if event.speaker not in run_events:
                previous_speaker = None
                continue
            if event.speaker != previous_speaker:
                run_speakers.append(event.speaker)
            run_events[event.speaker].append(event)
            previous_speaker = event.speaker

        base_hard = _base_hard(context)
        observed_soft = _observed_soft(context)
        timing_hard = _timing_hard(context, insufficient=not events)
        first_event = events[0] if events else None
        last_event = events[-1] if events else None
        conversation_metrics = (
            _metric(
                context,
                "conversation.total_communication_events",
                len(events),
                MetricUnit.COUNT,
                _evidence(events),
                hard=(
                    base_hard
                    | ({MissingDataReason.UNKNOWN_EVENT} if context.unknown_events else set())
                ),
                soft=observed_soft,
            ),
            _metric(
                context,
                "conversation.total_user_events",
                len(participant_events[ConversationEventSpeaker.USER]),
                MetricUnit.COUNT,
                _evidence(participant_events[ConversationEventSpeaker.USER]),
                hard=_participation_hard(context),
            ),
            _metric(
                context,
                "conversation.total_other_events",
                len(participant_events[ConversationEventSpeaker.OTHER]),
                MetricUnit.COUNT,
                _evidence(participant_events[ConversationEventSpeaker.OTHER]),
                hard=_participation_hard(context),
            ),
            _metric(
                context,
                "conversation.duration_seconds",
                duration,
                MetricUnit.SECONDS,
                _evidence(events),
                hard=timing_hard,
            ),
            _metric(
                context,
                "conversation.active_duration_seconds",
                active_duration,
                MetricUnit.SECONDS,
                _evidence(events),
                hard=timing_hard,
            ),
            _metric(
                context,
                "conversation.inactive_duration_seconds",
                inactive_duration,
                MetricUnit.SECONDS,
                _evidence(events),
                hard=timing_hard,
            ),
            _metric(
                context,
                "conversation.first_event_id",
                first_event.id if first_event is not None else UUID(int=0),
                MetricUnit.EVENT_ID,
                _evidence((first_event,) if first_event is not None else ()),
                hard=(
                    base_hard
                    | ({MissingDataReason.INSUFFICIENT_EVIDENCE} if first_event is None else set())
                ),
                soft=observed_soft,
            ),
            _metric(
                context,
                "conversation.last_event_id",
                last_event.id if last_event is not None else UUID(int=0),
                MetricUnit.EVENT_ID,
                _evidence((last_event,) if last_event is not None else ()),
                hard=(
                    base_hard
                    | ({MissingDataReason.INSUFFICIENT_EVIDENCE} if last_event is None else set())
                ),
                soft=observed_soft,
            ),
            _metric(
                context,
                "participation.conversation_starts",
                len(session_start_events),
                MetricUnit.COUNT,
                _evidence(session_start_events),
                hard=timing_hard,
            ),
        )

        participants: list[ParticipantAnalyticsV1] = []
        for speaker in (
            ConversationEventSpeaker.USER,
            ConversationEventSpeaker.OTHER,
        ):
            speaker_events = participant_events[speaker]
            speaker_starts = tuple(
                event for event in session_start_events if event.speaker == speaker
            )
            participation_hard = _participation_hard(context)
            share_hard = participation_hard | (
                {MissingDataReason.INSUFFICIENT_EVIDENCE} if not events else set()
            )
            participants.append(
                ParticipantAnalyticsV1(
                    speaker=speaker,
                    metrics=(
                        _metric(
                            context,
                            f"participant.{speaker.value}.communication_events",
                            len(speaker_events),
                            MetricUnit.COUNT,
                            _evidence(speaker_events),
                            hard=participation_hard,
                        ),
                        _metric(
                            context,
                            f"participant.{speaker.value}.participation_share_percent",
                            round(100 * len(speaker_events) / len(events), 6) if events else 0.0,
                            MetricUnit.PERCENT,
                            _evidence(events),
                            hard=share_hard,
                        ),
                        _metric(
                            context,
                            f"participant.{speaker.value}.initiations",
                            len(speaker_starts),
                            MetricUnit.COUNT,
                            _evidence(speaker_starts),
                            hard=timing_hard,
                        ),
                        _metric(
                            context,
                            f"participant.{speaker.value}.consecutive_runs",
                            run_speakers.count(speaker),
                            MetricUnit.COUNT,
                            _evidence(tuple(run_events[speaker])),
                            hard=participation_hard,
                        ),
                    ),
                )
            )

        response_hard = _timing_hard(context, insufficient=not response_latencies)
        if response_latencies:
            response_values = (
                sum(response_latencies) / len(response_latencies),
                float(median(response_latencies)),
                min(response_latencies),
                max(response_latencies),
            )
        else:
            response_values = (0.0, 0.0, 0.0, 0.0)
        timeline_metrics = tuple(
            _metric(
                context,
                identifier,
                value,
                MetricUnit.SECONDS,
                _evidence(response_events),
                hard=response_hard,
            )
            for identifier, value in zip(
                (
                    "timing.response_latency_mean_seconds",
                    "timing.response_latency_median_seconds",
                    "timing.response_latency_minimum_seconds",
                    "timing.response_latency_maximum_seconds",
                ),
                response_values,
                strict=True,
            )
        )
        return (
            ConversationAnalyticsV1(metrics=conversation_metrics),
            (participants[0], participants[1]),
            TimelineAnalyticsV1(metrics=timeline_metrics),
        )

    def _messages(self, context: _AnalysisContext) -> MessageAnalyticsV1:
        definitions = (
            ("messages.total", PARTICIPANT_EVENT_TYPES),
            ("messages.text", frozenset({ConversationEventType.TEXT_MESSAGE})),
            ("messages.emoji", frozenset({ConversationEventType.EMOJI_MESSAGE})),
            ("messages.media", MEDIA_EVENT_TYPES),
            ("messages.attachments", ATTACHMENT_EVENT_TYPES),
            ("messages.deleted_markers", frozenset({ConversationEventType.DELETED_MESSAGE})),
            (
                "messages.edited_markers",
                frozenset({ConversationEventType.EDITED_MESSAGE_MARKER}),
            ),
        )
        return MessageAnalyticsV1(
            metrics=tuple(
                _metric_for_type(context, identifier, event_types)
                for identifier, event_types in definitions
            )
        )

    def _questions_and_replies(
        self, context: _AnalysisContext
    ) -> tuple[QuestionAnalyticsV1, ReplyAnalyticsV1, MetricV1]:
        event_by_id = {event.id: event for event in context.accepted_events}
        questions = tuple(
            event
            for event in context.communication_events
            if event.event_type == ConversationEventType.TEXT_MESSAGE
            and event.text is not None
            and "?" in event.text
        )
        question_ids = {question.id for question in questions}
        reply_references = tuple(
            event
            for event in context.accepted_events
            if event.event_type == ConversationEventType.REPLY_REFERENCE
        )
        valid_relationships = tuple(
            relationship
            for relationship in context.relationships
            if relationship.id not in context.invalid_relationship_ids
            and relationship.relationship_type == ConversationEventRelationshipType.REPLY_TARGET
            and relationship.source_event_id in event_by_id
            and relationship.target_event_id in event_by_id
        )
        valid_source_ids = {relationship.source_event_id for relationship in valid_relationships}
        answered_ids = {
            relationship.target_event_id
            for relationship in valid_relationships
            if relationship.target_event_id in question_ids
        }
        question_relationships = tuple(
            relationship
            for relationship in valid_relationships
            if relationship.target_event_id in question_ids
        )
        answered = tuple(question for question in questions if question.id in answered_ids)
        unanswered = tuple(question for question in questions if question.id not in answered_ids)
        explicit = tuple(
            reference for reference in reply_references if reference.id in valid_source_ids
        )
        orphan = tuple(
            reference for reference in reply_references if reference.id not in valid_source_ids
        )
        relationship_hard = _relationship_hard(context)
        question_soft = _observed_soft(context)
        questions_result = QuestionAnalyticsV1(
            metrics=(
                _metric(
                    context,
                    "questions.total",
                    len(questions),
                    MetricUnit.COUNT,
                    _evidence(questions),
                    hard=_base_hard(context),
                    soft=question_soft,
                ),
                _metric(
                    context,
                    "questions.answered",
                    len(answered),
                    MetricUnit.COUNT,
                    _evidence(
                        answered,
                        question_relationships,
                        _relationship_event_ids(question_relationships),
                    ),
                    hard=(
                        relationship_hard
                        | ({MissingDataReason.UNKNOWN_EVENT} if context.unknown_events else set())
                    ),
                    soft=(
                        {MissingDataReason.INCOMPLETE_TIMELINE}
                        if context.incomplete_timeline
                        else set()
                    ),
                ),
                _metric(
                    context,
                    "questions.unanswered",
                    len(unanswered),
                    MetricUnit.COUNT,
                    _evidence(
                        unanswered,
                        question_relationships,
                        _relationship_event_ids(question_relationships),
                    ),
                    hard=(
                        relationship_hard
                        | ({MissingDataReason.UNKNOWN_EVENT} if context.unknown_events else set())
                    ),
                    soft=(
                        {MissingDataReason.INCOMPLETE_TIMELINE}
                        if context.incomplete_timeline
                        else set()
                    ),
                ),
            )
        )
        replies_result = ReplyAnalyticsV1(
            metrics=(
                _metric(
                    context,
                    "replies.explicit",
                    len(explicit),
                    MetricUnit.COUNT,
                    _evidence(
                        explicit,
                        valid_relationships,
                        _relationship_event_ids(valid_relationships),
                    ),
                    hard=relationship_hard,
                    soft=question_soft,
                ),
                _metric(
                    context,
                    "replies.orphan",
                    len(orphan),
                    MetricUnit.COUNT,
                    _evidence(orphan),
                    hard=relationship_hard,
                    soft=question_soft,
                ),
            )
        )

        timeline = context.communication_events
        exact_timing_hard = _timing_hard(context, insufficient=not timeline)
        unanswered_duration = 0.0
        unanswered_evidence: tuple[ConfirmedConversationEvent, ...] = ()
        if unanswered and timeline and not exact_timing_hard:
            earliest = min(
                unanswered,
                key=lambda event: event.timestamp if event.timestamp is not None else datetime.max,
            )
            last = timeline[-1]
            if earliest.timestamp is not None and last.timestamp is not None:
                unanswered_duration = _exact_seconds(earliest.timestamp, last.timestamp)
                unanswered_evidence = (earliest, last)
        unanswered_metric = _metric(
            context,
            "timing.unanswered_question_duration_seconds",
            unanswered_duration,
            MetricUnit.SECONDS,
            _evidence(
                unanswered_evidence,
                question_relationships,
                _relationship_event_ids(question_relationships),
            ),
            hard=exact_timing_hard | relationship_hard,
        )
        return questions_result, replies_result, unanswered_metric

    def _reactions(self, context: _AnalysisContext) -> ReactionAnalyticsV1:
        event_by_id = {event.id: event for event in context.accepted_events}
        reactions = tuple(
            event
            for event in context.accepted_events
            if event.event_type == ConversationEventType.REACTION
        )
        valid_relationships = tuple(
            relationship
            for relationship in context.relationships
            if relationship.id not in context.invalid_relationship_ids
            and relationship.relationship_type == ConversationEventRelationshipType.REACTION_TARGET
            and relationship.source_event_id in event_by_id
            and relationship.target_event_id in event_by_id
        )
        valid_source_ids = {relationship.source_event_id for relationship in valid_relationships}
        target_ids = {relationship.target_event_id for relationship in valid_relationships}
        sent_user = tuple(
            reaction for reaction in reactions if reaction.speaker == ConversationEventSpeaker.USER
        )
        sent_other = tuple(
            reaction for reaction in reactions if reaction.speaker == ConversationEventSpeaker.OTHER
        )
        received_user_relationships = tuple(
            relationship
            for relationship in valid_relationships
            if event_by_id[relationship.target_event_id].speaker == ConversationEventSpeaker.USER
        )
        received_other_relationships = tuple(
            relationship
            for relationship in valid_relationships
            if event_by_id[relationship.target_event_id].speaker == ConversationEventSpeaker.OTHER
        )
        unresolved_reaction = any(reaction.id not in valid_source_ids for reaction in reactions)
        grouped: dict[str, list[ConfirmedConversationEvent]] = {}
        for reaction in reactions:
            reaction_value = reaction.metadata.get("reaction")
            reaction_type = reaction_value if isinstance(reaction_value, str) else "unspecified"
            grouped.setdefault(reaction_type, []).append(reaction)
        by_type = tuple(
            ReactionTypeCountV1(
                reaction_type=reaction_type,
                count=len(grouped_events),
                evidence=_evidence(tuple(grouped_events)),
            )
            for reaction_type, grouped_events in sorted(grouped.items())
        )
        base_hard = _base_hard(context)
        relationship_hard = _relationship_hard(context)
        target_relationship_hard = relationship_hard | (
            {MissingDataReason.UNRESOLVED_RELATIONSHIP} if unresolved_reaction else set()
        )
        missing_participant_hard = (
            {MissingDataReason.MISSING_PARTICIPANT}
            if context.missing_participant
            or any(
                reaction.speaker
                not in {ConversationEventSpeaker.USER, ConversationEventSpeaker.OTHER}
                for reaction in reactions
            )
            else set()
        )
        target_participant_hard = (
            {MissingDataReason.MISSING_PARTICIPANT}
            if any(
                event_by_id[relationship.target_event_id].speaker
                not in {ConversationEventSpeaker.USER, ConversationEventSpeaker.OTHER}
                for relationship in valid_relationships
            )
            else set()
        )
        return ReactionAnalyticsV1(
            metrics=(
                _metric(
                    context,
                    "reactions.sent_by_user",
                    len(sent_user),
                    MetricUnit.COUNT,
                    _evidence(sent_user),
                    hard=base_hard | missing_participant_hard,
                    soft=_observed_soft(context),
                ),
                _metric(
                    context,
                    "reactions.sent_by_other",
                    len(sent_other),
                    MetricUnit.COUNT,
                    _evidence(sent_other),
                    hard=base_hard | missing_participant_hard,
                    soft=_observed_soft(context),
                ),
                _metric(
                    context,
                    "reactions.received_by_user",
                    len(received_user_relationships),
                    MetricUnit.COUNT,
                    _evidence(
                        relationships=received_user_relationships,
                        extra_event_ids=_relationship_event_ids(received_user_relationships),
                    ),
                    hard=target_relationship_hard | target_participant_hard,
                    soft=_observed_soft(context),
                ),
                _metric(
                    context,
                    "reactions.received_by_other",
                    len(received_other_relationships),
                    MetricUnit.COUNT,
                    _evidence(
                        relationships=received_other_relationships,
                        extra_event_ids=_relationship_event_ids(received_other_relationships),
                    ),
                    hard=target_relationship_hard | target_participant_hard,
                    soft=_observed_soft(context),
                ),
                _metric(
                    context,
                    "reactions.by_type",
                    by_type,
                    MetricUnit.REACTION_TYPE_COUNTS,
                    _evidence(reactions),
                    hard=base_hard,
                    soft=_observed_soft(context),
                ),
                _metric(
                    context,
                    "reactions.targets",
                    len(target_ids),
                    MetricUnit.COUNT,
                    _evidence(
                        relationships=valid_relationships,
                        extra_event_ids=_relationship_event_ids(valid_relationships),
                    ),
                    hard=target_relationship_hard,
                    soft=_observed_soft(context),
                ),
            )
        )

    def _media(self, context: _AnalysisContext) -> MediaAnalyticsV1:
        definitions = (
            ("media.images", ConversationEventType.IMAGE),
            ("media.videos", ConversationEventType.VIDEO),
            ("media.voice_notes", ConversationEventType.VOICE_NOTE),
            ("media.documents", ConversationEventType.DOCUMENT),
            ("media.links", ConversationEventType.LINK),
            ("media.locations", ConversationEventType.LOCATION),
        )
        return MediaAnalyticsV1(
            metrics=tuple(
                _metric_for_type(context, identifier, frozenset({event_type}))
                for identifier, event_type in definitions
            )
        )

    def _structure(self, context: _AnalysisContext) -> StructureAnalyticsV1:
        event_by_id = {event.id: event for event in context.active_events}
        duplicate_relationships = tuple(
            relationship
            for relationship in context.relationships
            if relationship.id not in context.invalid_relationship_ids
            and relationship.relationship_type == ConversationEventRelationshipType.DUPLICATE_OF
            and relationship.source_event_id in event_by_id
            and relationship.target_event_id in event_by_id
        )
        duplicate_events = tuple(
            event_by_id[event_id] for event_id in sorted(context.duplicate_event_ids, key=str)
        )
        structural_events = tuple(
            event
            for event in context.accepted_events
            if event.event_type in STRUCTURAL_COUNT_EVENT_TYPES
        )
        gap_ids = tuple(
            dict.fromkeys(
                boundary
                for gap in context.payload.timeline_gaps
                for boundary in (gap.before_event_id, gap.after_event_id)
                if boundary is not None
            )
        )
        relationship_soft = (
            {MissingDataReason.UNRESOLVED_RELATIONSHIP}
            if context.invalid_relationship_ids
            else set()
        )
        return StructureAnalyticsV1(
            metrics=(
                _metric(
                    context,
                    "structure.timeline_gaps",
                    len(context.payload.timeline_gaps),
                    MetricUnit.COUNT,
                    _evidence(extra_event_ids=gap_ids),
                ),
                _metric(
                    context,
                    "structure.duplicates",
                    len(context.duplicate_event_ids),
                    MetricUnit.COUNT,
                    _evidence(
                        duplicate_events,
                        duplicate_relationships,
                        _relationship_event_ids(duplicate_relationships),
                    ),
                    soft=relationship_soft,
                ),
                _metric(
                    context,
                    "structure.unknown_events",
                    len(context.unknown_events),
                    MetricUnit.COUNT,
                    _evidence(context.unknown_events),
                ),
                _metric(
                    context,
                    "structure.structural_events",
                    len(structural_events),
                    MetricUnit.COUNT,
                    _evidence(structural_events),
                    hard=_base_hard(context),
                    soft=_observed_soft(context),
                ),
            )
        )

    def _overall_quality(self, context: _AnalysisContext) -> QualityMetadataV1:
        reasons = _present_reasons(context)
        hard = reasons & {
            MissingDataReason.INCOMPLETE_REVIEW,
            MissingDataReason.PARTIAL_CONVERSATION,
        }
        return _quality(context, hard=hard, soft=reasons - hard)
