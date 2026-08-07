"""Phase 12 production-provider abstraction foundation tests."""

import asyncio
from dataclasses import FrozenInstanceError, replace
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID

import pytest

from app.ai.coaching_response_contracts import CoachingCapability
from app.ai.contracts import (
    AI_REQUEST_SCHEMA_VERSION,
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestPurpose,
    AIRequestRequirementsV1,
)
from app.ai.execution_contracts import (
    AIExecutionCompletedV1,
    AIExecutionRequestV1,
)
from app.ai.execution_pipeline import AIExecutionCoordinator
from app.ai.provider import MOCK_AI_PROVIDER_IDENTIFIER, MockAIProvider
from app.ai.provider_contracts import (
    AIProviderClassification,
    AIProviderCompatibilityFailureCode,
    AIProviderExecutionCapability,
    AIProviderFeatureFlagsV1,
    AIProviderHealthStatus,
    AIProviderLifecycleState,
    AIProviderMetadataV1,
    AIProviderRuntimeConfigurationV1,
    AIProviderSelectionRequestV1,
    AIProviderVisibility,
)
from app.ai.provider_factory import (
    AIProviderCreatedV1,
    AIProviderCreationRejectedV1,
    AIProviderFactory,
    AIProviderStructuralHealthEvaluator,
)
from app.ai.provider_registry import (
    AIProviderRegistrationError,
    AIProviderRegistry,
    build_default_provider_registry,
    deterministic_mock_provider_metadata,
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


def _selection_request(
    *,
    identifier: str | None = None,
    request_schema_version: str = AI_REQUEST_SCHEMA_VERSION,
    response_schema_versions: tuple[str, ...] = ("ai-coaching-response.v1",),
    execution_capabilities: tuple[AIProviderExecutionCapability, ...] = (
        AIProviderExecutionCapability.FOUNDATION_PLACEHOLDER,
    ),
    response_capabilities: tuple[CoachingCapability, ...] = (
        CoachingCapability.RESPONSE_SCHEMA,
        CoachingCapability.EVIDENCE_REFERENCES,
        CoachingCapability.EXPLANATION_PLACEHOLDERS,
        CoachingCapability.SAFETY_NOTICES,
    ),
    language: str = "en",
) -> AIProviderSelectionRequestV1:
    return AIProviderSelectionRequestV1(
        requested_provider_identifier=identifier,
        request_schema_version=request_schema_version,
        accepted_response_schema_versions=response_schema_versions,
        required_execution_capabilities=execution_capabilities,
        required_response_capabilities=response_capabilities,
        language=language,
    )


def _enabled_factory(
    registry: AIProviderRegistry | None = None,
) -> AIProviderFactory:
    return AIProviderFactory(
        registry or build_default_provider_registry(),
        AIProviderRuntimeConfigurationV1(
            feature_flags=AIProviderFeatureFlagsV1(
                ai_coaching_enabled=True,
                ai_mock_execution_enabled=True,
            )
        ),
    )


def _future_metadata() -> AIProviderMetadataV1:
    return replace(
        deterministic_mock_provider_metadata(),
        identifier="future-provider-placeholder.v1",
        version="0.0.0",
        family="future-provider-placeholder",
        lifecycle_state=AIProviderLifecycleState.INACTIVE,
        visibility=AIProviderVisibility.HIDDEN,
        classification=AIProviderClassification.PRODUCTION,
    )


def _uuid(value: int) -> UUID:
    return UUID(f"00000000-0000-4000-8000-{value:012d}")


def _execution_request() -> AIExecutionRequestV1:
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
        accepted_response_versions=("ai-coaching-response.v1",),
    )


def _analytics_source() -> AnalyticsInputV1:
    events = tuple(
        ConfirmedConversationEvent(
            id=_uuid(index),
            position=index - 1,
            event_type=ConversationEventType.TEXT_MESSAGE,
            speaker=speaker,
            text="synthetic reviewed message",
            timestamp=datetime(2026, 7, 25, 10, index, tzinfo=UTC),
            timestamp_is_estimated=False,
            raw_timestamp_text=None,
            source_image_index=None,
            source_region_id=None,
            ocr_confidence=None,
            classification_confidence=1.0,
            speaker_confidence=1.0,
            timestamp_confidence=1.0,
            relationship_confidence=None,
            requires_review=False,
            metadata={},
            deleted_at=None,
        )
        for index, speaker in (
            (1, ConversationEventSpeaker.USER),
            (2, ConversationEventSpeaker.OTHER),
        )
    )
    return AnalyticsInputV1(
        event_sequence=ConfirmedConversationEventSequence(
            schema_version="conversation-events.v1",
            events=events,
            relationships=(),
        ),
        review_status=AnalyticsReviewStatus.CONFIRMED,
    )


def test_default_registry_contains_only_active_internal_mock_metadata() -> None:
    registry = build_default_provider_registry()
    metadata = tuple(registry)

    assert len(registry) == 1
    assert metadata == (deterministic_mock_provider_metadata(),)
    assert metadata[0].identifier == MOCK_AI_PROVIDER_IDENTIFIER
    assert metadata[0].classification == AIProviderClassification.MOCK
    assert metadata[0].lifecycle_state == AIProviderLifecycleState.ACTIVE
    assert metadata[0].visibility == AIProviderVisibility.INTERNAL


def test_registry_rejects_duplicate_and_active_production_registrations() -> None:
    mock = deterministic_mock_provider_metadata()
    with pytest.raises(AIProviderRegistrationError):
        AIProviderRegistry((mock, mock))
    with pytest.raises(AIProviderRegistrationError):
        AIProviderRegistry(
            (
                replace(
                    mock,
                    identifier="future-provider-placeholder.v1",
                    classification=AIProviderClassification.PRODUCTION,
                ),
            )
        )


def test_inactive_future_metadata_can_be_registered_but_not_created() -> None:
    future = _future_metadata()
    registry = AIProviderRegistry(
        (
            deterministic_mock_provider_metadata(),
            future,
        )
    )
    result = _enabled_factory(registry).create(
        _selection_request(identifier="future-provider-placeholder.v1")
    )

    assert isinstance(result, AIProviderCreationRejectedV1)
    assert {failure.code for failure in result.failures} >= {
        AIProviderCompatibilityFailureCode.PROVIDER_INACTIVE,
        AIProviderCompatibilityFailureCode.PROVIDER_NOT_MOCK,
    }


@pytest.mark.parametrize(
    "selection_request",
    [
        _selection_request(request_schema_version="ai-request.v999"),
        _selection_request(response_schema_versions=("ai-coaching-response.v999",)),
        _selection_request(response_capabilities=(CoachingCapability.COACHING_GUIDANCE,)),
        _selection_request(language="und"),
    ],
)
def test_factory_rejects_incompatible_schema_capability_and_language(
    selection_request: AIProviderSelectionRequestV1,
) -> None:
    result = _enabled_factory().create(selection_request)

    assert isinstance(result, AIProviderCreationRejectedV1)
    assert result.failures


def test_factory_rejects_unsupported_provider_and_disabled_flags() -> None:
    unsupported = _enabled_factory().create(
        _selection_request(identifier="unsupported-provider.v1")
    )
    disabled = AIProviderFactory.default().create(_selection_request())

    assert isinstance(unsupported, AIProviderCreationRejectedV1)
    assert unsupported.failures[0].code == (AIProviderCompatibilityFailureCode.PROVIDER_UNSUPPORTED)
    assert isinstance(disabled, AIProviderCreationRejectedV1)
    assert disabled.failures[0].code == (AIProviderCompatibilityFailureCode.FEATURE_FLAG_DISABLED)


def test_selection_is_deterministic_and_factory_is_mock_exclusive() -> None:
    factory = _enabled_factory()
    first = factory.create(_selection_request())
    second = factory.create(_selection_request())

    assert isinstance(first, AIProviderCreatedV1)
    assert isinstance(second, AIProviderCreatedV1)
    assert first.metadata == second.metadata
    assert isinstance(first.provider, MockAIProvider)
    assert first.provider.identifier == MOCK_AI_PROVIDER_IDENTIFIER
    assert first.health.status == AIProviderHealthStatus.AVAILABLE


def test_health_is_structural_and_lifecycle_aware() -> None:
    evaluator = AIProviderStructuralHealthEvaluator()
    metadata = deterministic_mock_provider_metadata()
    enabled = AIProviderFeatureFlagsV1(
        ai_coaching_enabled=True,
        ai_mock_execution_enabled=True,
    )

    assert evaluator.evaluate(metadata, enabled).status == (AIProviderHealthStatus.AVAILABLE)
    assert evaluator.evaluate(metadata, AIProviderFeatureFlagsV1()).status == (
        AIProviderHealthStatus.DISABLED
    )
    assert (
        evaluator.evaluate(
            replace(metadata, lifecycle_state=AIProviderLifecycleState.INACTIVE),
            enabled,
        ).status
        == AIProviderHealthStatus.INACTIVE
    )


def test_provider_contracts_are_immutable_and_validate_schema_metadata() -> None:
    metadata = deterministic_mock_provider_metadata()

    with pytest.raises(FrozenInstanceError):
        delattr(metadata, "identifier")
    with pytest.raises(ValueError):
        replace(
            metadata,
            supported_request_schema_versions=(
                AI_REQUEST_SCHEMA_VERSION,
                AI_REQUEST_SCHEMA_VERSION,
            ),
        )
    with pytest.raises(ValueError):
        replace(metadata, maximum_response_schema_version="unsupported.v1")


def test_provider_foundation_has_no_external_network_or_sdk_capability() -> None:
    ai_directory = Path(__file__).parents[1] / "app" / "ai"
    source = "\n".join(
        (ai_directory / name).read_text(encoding="utf-8")
        for name in (
            "provider.py",
            "provider_contracts.py",
            "provider_registry.py",
            "provider_factory.py",
        )
    )

    for forbidden_import in (
        "import httpx",
        "import requests",
        "import socket",
        "import urllib",
        "import openai",
        "import anthropic",
        "import google.generativeai",
    ):
        assert forbidden_import not in source


def test_execution_pipeline_resolves_only_mock_through_registry_factory() -> None:
    coordinator = AIExecutionCoordinator(
        provider=None,
        provider_factory=_enabled_factory(),
        execution_enabled=True,
        mock_enabled=True,
    )

    result = asyncio.run(
        coordinator.execute(
            _execution_request(),
            _analytics_source(),
        )
    )

    assert isinstance(result, AIExecutionCompletedV1)
    assert result.projection.sections[-1].item_localization_keys == (
        "coaching.foundation.no_coaching_generated",
    )
