"""Phase 10 deterministic, default-off AI execution pipeline tests."""

import asyncio
from collections.abc import Awaitable, Callable
from dataclasses import FrozenInstanceError
from datetime import UTC, datetime
from uuid import UUID

import pytest

from app.ai.coaching_response_codec import StructuredCoachingResponseCodec
from app.ai.coaching_response_contracts import (
    CoachingResponseParseFailureCode,
    CoachingResponseParseFailureV1,
    CoachingResponseParseResultV1,
    CoachingResponseValidationFailureCode,
    CoachingResponseValidationFailureV1,
    StructuredCoachingResponseV1,
)
from app.ai.coaching_response_validation import (
    StructuredCoachingResponseValidator,
)
from app.ai.contracts import (
    AIEvidencePackageV1,
    AIPromptTemplateV1,
    AIRawProviderResponseV1,
    AIRequestIntentV1,
    AIRequestPurpose,
    AIRequestRequirementsV1,
    AIRequestV1,
)
from app.ai.execution_contracts import (
    AIExecutionCompletedV1,
    AIExecutionDiagnosticStatus,
    AIExecutionFailureCode,
    AIExecutionFailureV1,
    AIExecutionRequestV1,
    AIExecutionResultV1,
    AIExecutionStage,
    AIExecutionState,
)
from app.ai.execution_control import (
    AIExecutionAwaiter,
    AIExecutionTimedOut,
    StaticAIExecutionControl,
)
from app.ai.execution_pipeline import AIExecutionCoordinator
from app.ai.provider import (
    MOCK_AI_PROVIDER_IDENTIFIER,
    AIProvider,
    MockAIProvider,
)
from app.domain.conversation_analytics import (
    AnalyticsInputV1,
    AnalyticsReviewStatus,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventSequence,
    ConversationEventSpeaker,
    ConversationEventType,
)

PRIVATE_SENTINEL = "private synthetic pipeline message"


def _uuid(value: int) -> UUID:
    return UUID(f"00000000-0000-4000-8000-{value:012d}")


def _event(
    value: int,
    position: int,
    speaker: ConversationEventSpeaker,
) -> ConfirmedConversationEvent:
    return ConfirmedConversationEvent(
        id=_uuid(value),
        position=position,
        event_type=ConversationEventType.TEXT_MESSAGE,
        speaker=speaker,
        text=PRIVATE_SENTINEL,
        timestamp=datetime(2026, 7, 24, 10, value, tzinfo=UTC),
        timestamp_is_estimated=False,
        raw_timestamp_text="private raw timestamp",
        source_image_index=0,
        source_region_id="private source region",
        ocr_confidence=0.99,
        classification_confidence=0.99,
        speaker_confidence=0.99,
        timestamp_confidence=0.99,
        relationship_confidence=None,
        requires_review=False,
        metadata={"private": PRIVATE_SENTINEL},
        deleted_at=None,
    )


def _source(
    *,
    review_status: AnalyticsReviewStatus = AnalyticsReviewStatus.CONFIRMED,
) -> AnalyticsInputV1:
    return AnalyticsInputV1(
        event_sequence=ConfirmedConversationEventSequence(
            schema_version="conversation-events.v1",
            events=(
                _event(1, 0, ConversationEventSpeaker.USER),
                _event(2, 1, ConversationEventSpeaker.OTHER),
            ),
            relationships=(),
        ),
        review_status=review_status,
    )


def _request(
    *,
    accepted_versions: tuple[str, ...] = ("ai-coaching-response.v1",),
) -> AIExecutionRequestV1:
    return AIExecutionRequestV1(
        request_id=_uuid(10),
        requirements=AIRequestRequirementsV1(
            required_metric_identifiers=(
                "messages.total",
                "structure.unknown_events",
            )
        ),
        template=AIPromptTemplateV1(
            identifier="foundation-validation",
            template_version="1.0.0",
            locale="en",
            input_slots=("evidence",),
        ),
        intent=AIRequestIntentV1(purpose=AIRequestPurpose.FOUNDATION_VALIDATION),
        accepted_response_versions=accepted_versions,
    )


def _run(
    *,
    provider: AIProvider | None = None,
    execution_enabled: bool = True,
    mock_enabled: bool = True,
    source: AnalyticsInputV1 | None = None,
    request: AIExecutionRequestV1 | None = None,
    control: StaticAIExecutionControl | None = None,
    codec: StructuredCoachingResponseCodec | None = None,
    validator: StructuredCoachingResponseValidator | None = None,
    awaiter: AIExecutionAwaiter | None = None,
) -> AIExecutionResultV1:
    coordinator = AIExecutionCoordinator(
        provider=provider if provider is not None else MockAIProvider(),
        execution_enabled=execution_enabled,
        mock_enabled=mock_enabled,
        control=control,
        structured_response_codec=codec,
        response_validator=validator,
        awaiter=awaiter,
    )
    return asyncio.run(
        coordinator.execute(
            request or _request(),
            source or _source(),
        )
    )


def test_complete_pipeline_is_deterministic_ordered_and_content_free() -> None:
    first = _run()
    second = _run()

    assert isinstance(first, AIExecutionCompletedV1)
    assert first == second
    assert first.state == AIExecutionState.COMPLETED
    assert [item.stage for item in first.diagnostics] == list(AIExecutionStage)
    assert [item.sequence for item in first.diagnostics] == list(range(len(first.diagnostics)))
    assert {item.status for item in first.diagnostics} == {AIExecutionDiagnosticStatus.PASSED}
    assert first.projection.response_id == first.context.response_id
    assert PRIVATE_SENTINEL not in repr(first)
    assert "private raw timestamp" not in repr(first)


def test_execution_contracts_are_immutable_and_request_is_content_free() -> None:
    request = _request()

    assert PRIVATE_SENTINEL not in repr(request)
    with pytest.raises(FrozenInstanceError):
        delattr(request, "requirements")


@pytest.mark.parametrize(
    ("execution_enabled", "mock_enabled", "expected"),
    [
        (False, True, AIExecutionFailureCode.EXECUTION_DISABLED),
        (True, False, AIExecutionFailureCode.MOCK_DISABLED),
    ],
)
def test_execution_and_mock_are_disabled_independently(
    execution_enabled: bool,
    mock_enabled: bool,
    expected: AIExecutionFailureCode,
) -> None:
    result = _run(
        execution_enabled=execution_enabled,
        mock_enabled=mock_enabled,
    )

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == expected
    assert result.state == AIExecutionState.DISABLED


def test_unsupported_response_version_stops_before_analytics() -> None:
    result = _run(request=_request(accepted_versions=("unknown.v1",)))

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.UNSUPPORTED_RESPONSE_VERSION
    assert result.state == AIExecutionState.UNSUPPORTED
    assert [item.stage for item in result.diagnostics] == [
        AIExecutionStage.RECEIVED,
        AIExecutionStage.VERSION_NEGOTIATION,
    ]


def test_incomplete_review_stops_at_safety_with_structured_failures() -> None:
    result = _run(source=_source(review_status=AnalyticsReviewStatus.INCOMPLETE_REVIEW))

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.SAFETY_REJECTED
    assert result.safety_failures
    assert result.diagnostics[-1].stage == AIExecutionStage.SAFETY
    assert AIExecutionStage.REQUEST not in {item.stage for item in result.diagnostics}


@pytest.mark.parametrize(
    ("control", "state", "code", "status"),
    [
        (
            StaticAIExecutionControl(cancel_before=AIExecutionStage.PROVIDER),
            AIExecutionState.CANCELLED,
            AIExecutionFailureCode.CANCELLED,
            AIExecutionDiagnosticStatus.CANCELLED,
        ),
        (
            StaticAIExecutionControl(timeout_before=AIExecutionStage.STRUCTURED_RESPONSE_PARSER),
            AIExecutionState.TIMED_OUT,
            AIExecutionFailureCode.TIMED_OUT,
            AIExecutionDiagnosticStatus.TIMED_OUT,
        ),
    ],
)
def test_cancellation_and_timeout_propagate_at_stage_boundaries(
    control: StaticAIExecutionControl,
    state: AIExecutionState,
    code: AIExecutionFailureCode,
    status: AIExecutionDiagnosticStatus,
) -> None:
    result = _run(control=control)

    assert isinstance(result, AIExecutionFailureV1)
    assert result.state == state
    assert result.code == code
    assert result.diagnostics[-1].status == status
    assert result.diagnostics[-1].stage in {
        AIExecutionStage.PROVIDER,
        AIExecutionStage.STRUCTURED_RESPONSE_PARSER,
    }


def test_provider_unavailable_and_provider_failure_are_content_safe() -> None:
    class FailingProvider:
        @property
        def identifier(self) -> str:
            return MOCK_AI_PROVIDER_IDENTIFIER

        async def complete(
            self,
            request: AIRequestV1,
        ) -> AIRawProviderResponseV1:
            raise RuntimeError(PRIVATE_SENTINEL)

    unavailable = AIExecutionCoordinator(
        provider=None,
        execution_enabled=True,
        mock_enabled=True,
    )
    unavailable_result = asyncio.run(unavailable.execute(_request(), _source()))
    failed = _run(provider=FailingProvider())

    assert isinstance(unavailable_result, AIExecutionFailureV1)
    assert unavailable_result.code == AIExecutionFailureCode.PROVIDER_UNAVAILABLE
    assert isinstance(failed, AIExecutionFailureV1)
    assert failed.code == AIExecutionFailureCode.PROVIDER_FAILURE
    assert PRIVATE_SENTINEL not in repr(failed)


def test_async_timeout_abstraction_wraps_provider_without_leaking_content() -> None:
    class TimeoutAwaiter:
        async def run_provider(
            self,
            operation: Callable[
                [],
                Awaitable[AIRawProviderResponseV1],
            ],
        ) -> AIRawProviderResponseV1:
            raise AIExecutionTimedOut

    result = _run(awaiter=TimeoutAwaiter())

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.TIMED_OUT
    assert result.state == AIExecutionState.TIMED_OUT
    assert result.diagnostics[-1].stage == AIExecutionStage.PROVIDER
    assert result.diagnostics[-1].status == AIExecutionDiagnosticStatus.TIMED_OUT


def test_invalid_provider_payload_stops_at_provider_parser() -> None:
    class InvalidProvider:
        @property
        def identifier(self) -> str:
            return MOCK_AI_PROVIDER_IDENTIFIER

        async def complete(
            self,
            request: AIRequestV1,
        ) -> AIRawProviderResponseV1:
            return AIRawProviderResponseV1(
                payload='{"private":"' + PRIVATE_SENTINEL + '"}',
                provider_identifier=self.identifier,
            )

    result = _run(provider=InvalidProvider())

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.PROVIDER_RESPONSE_INVALID
    assert result.diagnostics[-1].stage == AIExecutionStage.PROVIDER_RESPONSE_PARSER
    assert PRIVATE_SENTINEL not in repr(result)


def test_structured_parser_failure_stops_before_response_validation() -> None:
    class InvalidCodec(StructuredCoachingResponseCodec):
        def parse(self, payload: str) -> CoachingResponseParseResultV1:
            return CoachingResponseParseFailureV1(CoachingResponseParseFailureCode.INVALID_SHAPE)

    result = _run(codec=InvalidCodec())

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.STRUCTURED_RESPONSE_PARSE_FAILURE
    assert result.diagnostics[-1].stage == AIExecutionStage.STRUCTURED_RESPONSE_PARSER


def test_response_validation_failure_is_structured_and_stops_projection() -> None:
    class RejectingValidator(StructuredCoachingResponseValidator):
        def validate(
            self,
            response: StructuredCoachingResponseV1,
            *,
            evidence_package_id: UUID,
            evidence: AIEvidencePackageV1,
        ) -> tuple[CoachingResponseValidationFailureV1, ...]:
            return (
                CoachingResponseValidationFailureV1(
                    CoachingResponseValidationFailureCode.FORBIDDEN_EVENT_REFERENCE,
                    "synthetic-reference",
                ),
            )

    result = _run(validator=RejectingValidator())

    assert isinstance(result, AIExecutionFailureV1)
    assert result.code == AIExecutionFailureCode.RESPONSE_VALIDATION_FAILURE
    assert result.response_failures
    assert result.diagnostics[-1].stage == AIExecutionStage.RESPONSE_VALIDATION
    assert AIExecutionStage.RENDERER_PROJECTION not in {item.stage for item in result.diagnostics}


def test_execution_ids_change_only_with_deterministic_request_inputs() -> None:
    first = _run()
    second = _run()
    changed = _run(
        request=AIExecutionRequestV1(
            request_id=_uuid(99),
            requirements=_request().requirements,
            template=_request().template,
            intent=_request().intent,
            accepted_response_versions=("ai-coaching-response.v1",),
        )
    )

    assert isinstance(first, AIExecutionCompletedV1)
    assert isinstance(second, AIExecutionCompletedV1)
    assert isinstance(changed, AIExecutionCompletedV1)
    assert first.context == second.context
    assert first.context.execution_id != changed.context.execution_id
