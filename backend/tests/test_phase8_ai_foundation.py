"""Phase 8 provider-neutral AI foundation tests with synthetic content only."""

import asyncio
import json
from dataclasses import FrozenInstanceError, replace
from datetime import UTC, datetime
from typing import Literal, cast
from uuid import UUID

import pytest

from app.ai.contracts import (
    AIOrchestrationCompletedV1,
    AIOrchestrationDisabledV1,
    AIOrchestrationProcessingFailureV1,
    AIOrchestrationRejectedV1,
    AIOrchestrationResultV1,
    AIProcessingFailureCode,
    AIPromptTemplateV1,
    AIRawProviderResponseV1,
    AIRequestIntentV1,
    AIRequestPurpose,
    AIRequestRequirementsV1,
    AIRequestV1,
    AIResponseStatus,
    AISafetyFailureCode,
)
from app.ai.evidence import AIEvidenceBuilder
from app.ai.orchestration import AIOrchestrator
from app.ai.provider import AIProvider, MockAIProvider
from app.ai.response_parser import AIResponseParseError, AIResponseParser
from app.domain.conversation_analytics import (
    AnalyticsInputV1,
    AnalyticsResultV1,
    AnalyticsReviewStatus,
    TimelineGapV1,
)
from app.domain.conversation_analytics_engine import (
    DeterministicConversationAnalyticsEngine,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventRelationship,
    ConfirmedConversationEventSequence,
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
)

PRIVATE_SENTINEL = "private synthetic content must not cross the boundary"


def _uuid(value: int) -> UUID:
    return UUID(f"00000000-0000-4000-8000-{value:012d}")


def _event(
    value: int,
    position: int,
    event_type: ConversationEventType,
    speaker: ConversationEventSpeaker,
    *,
    requires_review: bool = False,
    deleted: bool = False,
) -> ConfirmedConversationEvent:
    return ConfirmedConversationEvent(
        id=_uuid(value),
        position=position,
        event_type=event_type,
        speaker=speaker,
        text=PRIVATE_SENTINEL,
        timestamp=datetime(2026, 7, 24, 9, value, tzinfo=UTC),
        timestamp_is_estimated=False,
        raw_timestamp_text="private raw timestamp",
        source_image_index=0,
        source_region_id="private source region",
        ocr_confidence=0.99,
        classification_confidence=0.99,
        speaker_confidence=0.99,
        timestamp_confidence=0.99,
        relationship_confidence=None,
        requires_review=requires_review,
        metadata={"private": PRIVATE_SENTINEL},
        deleted_at=datetime(2026, 7, 24, tzinfo=UTC) if deleted else None,
    )


def _source(
    *,
    include_unknown: bool = False,
    include_excluded: bool = False,
    review_status: AnalyticsReviewStatus = AnalyticsReviewStatus.CONFIRMED,
    incomplete_timeline: bool = False,
    partial: bool = False,
) -> AnalyticsInputV1:
    events = [
        _event(
            1,
            0,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.USER,
        ),
        _event(
            2,
            1,
            ConversationEventType.TEXT_MESSAGE,
            ConversationEventSpeaker.OTHER,
        ),
    ]
    relationships: list[ConfirmedConversationEventRelationship] = [
        ConfirmedConversationEventRelationship(
            id=_uuid(20),
            source_event_id=_uuid(2),
            target_event_id=_uuid(1),
            relationship_type=ConversationEventRelationshipType.REPLY_TARGET,
            confidence=0.95,
            metadata={"private": PRIVATE_SENTINEL},
        )
    ]
    if include_unknown:
        events.append(
            _event(
                3,
                2,
                ConversationEventType.UNKNOWN,
                ConversationEventSpeaker.UNKNOWN,
            )
        )
    if include_excluded:
        events.extend(
            (
                _event(
                    4,
                    2,
                    ConversationEventType.DELETED_MESSAGE,
                    ConversationEventSpeaker.OTHER,
                ),
                _event(
                    5,
                    3,
                    ConversationEventType.TEXT_MESSAGE,
                    ConversationEventSpeaker.USER,
                    requires_review=True,
                ),
                _event(
                    6,
                    4,
                    ConversationEventType.TEXT_MESSAGE,
                    ConversationEventSpeaker.USER,
                    deleted=True,
                ),
                _event(
                    7,
                    5,
                    ConversationEventType.TEXT_MESSAGE,
                    ConversationEventSpeaker.USER,
                ),
            )
        )
        relationships.append(
            ConfirmedConversationEventRelationship(
                id=_uuid(21),
                source_event_id=_uuid(7),
                target_event_id=_uuid(1),
                relationship_type=ConversationEventRelationshipType.DUPLICATE_OF,
                confidence=0.95,
                metadata={},
            )
        )
    return AnalyticsInputV1(
        event_sequence=ConfirmedConversationEventSequence(
            schema_version="conversation-events.v1",
            events=tuple(events),
            relationships=tuple(relationships),
        ),
        review_status=review_status,
        timeline_gaps=(TimelineGapV1(after_event_id=_uuid(1)),) if incomplete_timeline else (),
        is_partial=partial,
    )


def _requirements(*, maximum_unknown_events: int = 0) -> AIRequestRequirementsV1:
    return AIRequestRequirementsV1(
        required_metric_identifiers=(
            "messages.total",
            "structure.unknown_events",
        ),
        maximum_unknown_events=maximum_unknown_events,
    )


def _template() -> AIPromptTemplateV1:
    return AIPromptTemplateV1(
        identifier="foundation-validation",
        template_version="1.0.0",
        locale="en",
        input_slots=("evidence",),
    )


def _intent(*, reconstruct_deleted: bool = False) -> AIRequestIntentV1:
    return AIRequestIntentV1(
        purpose=AIRequestPurpose.FOUNDATION_VALIDATION,
        requests_deleted_content_reconstruction=reconstruct_deleted,
    )


def _analytics(source: AnalyticsInputV1) -> AnalyticsResultV1:
    return DeterministicConversationAnalyticsEngine().analyze(source)


def _run(
    source: AnalyticsInputV1,
    *,
    enabled: bool,
    provider: AIProvider | None = None,
    requirements: AIRequestRequirementsV1 | None = None,
    template: AIPromptTemplateV1 | None = None,
    intent: AIRequestIntentV1 | None = None,
) -> AIOrchestrationResultV1:
    orchestrator = AIOrchestrator(
        provider or MockAIProvider(),
        feature_enabled=enabled,
    )
    return asyncio.run(
        orchestrator.execute(
            request_id=_uuid(100),
            source=source,
            analytics=_analytics(source),
            requirements=requirements or _requirements(),
            template=template or _template(),
            intent=intent or _intent(),
        )
    )


def test_contracts_are_immutable_and_evidence_is_content_minimized() -> None:
    source = _source(include_excluded=True)
    evidence = AIEvidenceBuilder().build(
        source.event_sequence,
        _analytics(source),
        _requirements(),
    )

    assert [event.event_id for event in evidence.context.events] == [_uuid(1), _uuid(2)]
    assert [relationship.relationship_id for relationship in evidence.context.relationships] == [
        _uuid(20)
    ]
    assert PRIVATE_SENTINEL not in repr(evidence)
    assert "private raw timestamp" not in repr(evidence)
    assert "private source region" not in repr(evidence)
    with pytest.raises(FrozenInstanceError):
        delattr(evidence.context, "events")


def test_evidence_packaging_is_deterministic_and_metric_scoped() -> None:
    source = _source()
    analytics = _analytics(source)
    builder = AIEvidenceBuilder()

    first = builder.build(source.event_sequence, analytics, _requirements())
    second = builder.build(source.event_sequence, analytics, _requirements())

    assert first == second
    assert [metric.identifier for metric in first.analytics] == [
        "messages.total",
        "structure.unknown_events",
    ]


def test_feature_flag_stops_before_evidence_or_provider_work() -> None:
    class FailingProvider:
        @property
        def identifier(self) -> str:
            return "must-not-run"

        async def complete(self, request: AIRequestV1) -> AIRawProviderResponseV1:
            raise AssertionError("provider must not be called")

    result = _run(_source(), enabled=False, provider=FailingProvider())

    assert isinstance(result, AIOrchestrationDisabledV1)


def test_enabled_mock_path_returns_only_structured_placeholder() -> None:
    result = _run(_source(), enabled=True)

    assert isinstance(result, AIOrchestrationCompletedV1)
    assert result.response.status == AIResponseStatus.FOUNDATION_PLACEHOLDER
    assert result.response.evidence_event_ids == (_uuid(1), _uuid(2))
    assert result.response.limitations == (
        "mock_foundation_only",
        "no_coaching_generated",
    )
    assert PRIVATE_SENTINEL not in repr(result)


@pytest.mark.parametrize(
    ("source", "intent", "expected"),
    [
        (
            _source(review_status=AnalyticsReviewStatus.INCOMPLETE_REVIEW),
            _intent(),
            AISafetyFailureCode.INCOMPLETE_REVIEW,
        ),
        (
            _source(incomplete_timeline=True),
            _intent(),
            AISafetyFailureCode.INCOMPLETE_TIMELINE,
        ),
        (
            _source(partial=True),
            _intent(),
            AISafetyFailureCode.PARTIAL_CONVERSATION,
        ),
        (
            _source(),
            _intent(reconstruct_deleted=True),
            AISafetyFailureCode.DELETED_CONTENT_RECONSTRUCTION_REQUESTED,
        ),
    ],
)
def test_safety_validation_fails_closed(
    source: AnalyticsInputV1,
    intent: AIRequestIntentV1,
    expected: AISafetyFailureCode,
) -> None:
    result = _run(source, enabled=True, intent=intent)

    assert isinstance(result, AIOrchestrationRejectedV1)
    assert expected in {failure.code for failure in result.failures}


def test_unknown_event_threshold_is_explicit_and_enforced() -> None:
    source = _source(include_unknown=True)
    evidence = AIEvidenceBuilder().build(
        source.event_sequence,
        _analytics(source),
        _requirements(maximum_unknown_events=1),
    )

    rejected = _run(source, enabled=True)
    allowed = _run(
        source,
        enabled=True,
        requirements=_requirements(maximum_unknown_events=1),
    )

    assert isinstance(rejected, AIOrchestrationRejectedV1)
    assert AISafetyFailureCode.UNKNOWN_EVENT_THRESHOLD_EXCEEDED in {
        failure.code for failure in rejected.failures
    }
    assert isinstance(allowed, AIOrchestrationCompletedV1)
    assert _uuid(3) not in allowed.response.evidence_event_ids
    assert all(_uuid(3) not in metric.event_ids for metric in evidence.analytics)


def test_bad_request_contract_schemas_and_missing_prompt_evidence_are_rejected() -> None:
    invalid_prompt = replace(
        _template(),
        schema_version=cast(Literal["ai-prompt-template.v1"], "invalid"),
    )
    invalid_requirements = replace(
        _requirements(),
        schema_version=cast(Literal["ai-request-requirements.v1"], "invalid"),
    )
    invalid_intent = replace(
        _intent(),
        schema_version=cast(Literal["ai-request-intent.v1"], "invalid"),
    )
    missing_evidence_slot = replace(_template(), input_slots=())

    results = (
        _run(_source(), enabled=True, template=invalid_prompt),
        _run(_source(), enabled=True, requirements=invalid_requirements),
        _run(_source(), enabled=True, intent=invalid_intent),
        _run(_source(), enabled=True, template=missing_evidence_slot),
    )

    assert all(isinstance(result, AIOrchestrationRejectedV1) for result in results)
    codes = [
        {failure.code for failure in result.failures}
        for result in results
        if isinstance(result, AIOrchestrationRejectedV1)
    ]
    assert AISafetyFailureCode.INVALID_PROMPT_TEMPLATE_SCHEMA in codes[0]
    assert AISafetyFailureCode.INVALID_REQUEST_REQUIREMENTS_SCHEMA in codes[1]
    assert AISafetyFailureCode.INVALID_REQUEST_INTENT_SCHEMA in codes[2]
    assert AISafetyFailureCode.REQUIRED_EVIDENCE_MISSING in codes[3]


def test_missing_or_unsupported_required_metric_is_rejected() -> None:
    source = _source()
    result = _run(
        source,
        enabled=True,
        requirements=AIRequestRequirementsV1(
            required_metric_identifiers=(
                "missing.metric",
                "structure.unknown_events",
            )
        ),
    )

    assert isinstance(result, AIOrchestrationRejectedV1)
    assert AISafetyFailureCode.REQUIRED_ANALYTICS_MISSING in {
        failure.code for failure in result.failures
    }


def test_provider_failure_returns_content_safe_processing_error() -> None:
    class FailingProvider:
        @property
        def identifier(self) -> str:
            return "failing-provider"

        async def complete(self, request: AIRequestV1) -> AIRawProviderResponseV1:
            raise RuntimeError(PRIVATE_SENTINEL)

    result = _run(_source(), enabled=True, provider=FailingProvider())

    assert result == AIOrchestrationProcessingFailureV1(AIProcessingFailureCode.PROVIDER_FAILURE)
    assert PRIVATE_SENTINEL not in repr(result)


def test_invalid_provider_payload_returns_safe_error_without_payload() -> None:
    class InvalidProvider:
        @property
        def identifier(self) -> str:
            return "invalid-provider"

        async def complete(self, request: AIRequestV1) -> AIRawProviderResponseV1:
            return AIRawProviderResponseV1(
                payload=json.dumps({"secret": PRIVATE_SENTINEL}),
                provider_identifier=self.identifier,
            )

    result = _run(_source(), enabled=True, provider=InvalidProvider())

    assert result == AIOrchestrationProcessingFailureV1(
        AIProcessingFailureCode.INVALID_PROVIDER_RESPONSE
    )
    assert PRIVATE_SENTINEL not in repr(result)


def test_parser_rejects_extra_keys_and_never_echoes_payload() -> None:
    raw = AIRawProviderResponseV1(
        payload=json.dumps(
            {
                "schema_version": "ai-response.v1",
                "provider_identifier": "mock",
                "status": "foundation_placeholder",
                "request_schema_version": "ai-request.v1",
                "prompt_identifier": "foundation-validation",
                "prompt_template_version": "1.0.0",
                "evidence_event_ids": [],
                "limitations": ["mock_foundation_only"],
                "unexpected": PRIVATE_SENTINEL,
            }
        ),
        provider_identifier="mock",
    )

    with pytest.raises(AIResponseParseError) as error:
        AIResponseParser().parse(raw)

    assert str(error.value) == "invalid_provider_response"
    assert PRIVATE_SENTINEL not in str(error.value)
