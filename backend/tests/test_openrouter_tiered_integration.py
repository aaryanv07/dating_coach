"""OpenRouter tier routing, privacy, schema, and vertical-slice tests."""

from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any, cast
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.ai.openrouter import (
    OPENROUTER_PROVIDER_IDENTIFIER,
    OpenRouterCoachOutputV1,
    OpenRouterConversationContextV1,
    OpenRouterObservationV1,
    OpenRouterProviderFailure,
    OpenRouterProviderFailureCode,
    OpenRouterProviderResultV1,
    OpenRouterProviderUsageV1,
    OpenRouterReplyDraftV1,
    OpenRouterTieredProvider,
    build_openrouter_context,
    openrouter_coach_output_json_schema,
    privacy_safe_openrouter_user_identifier,
)
from app.core.config import (
    OPENROUTER_FREE_MODEL,
    OPENROUTER_PAID_MODEL,
    Settings,
    SettingsValidationError,
    validate_settings,
)
from app.db.models import SubscriptionEntitlement, User
from app.db.session import SessionFactory
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConversationEventSpeaker,
    ConversationEventType,
)
from app.subscriptions.runtime import AIUsageRepository, usage_policy_from_settings

PRIVATE_SENTINEL = "private synthetic openrouter conversation text"
_EVENT_A = UUID("00000000-0000-4000-8000-000000002101")
_EVENT_B = UUID("00000000-0000-4000-8000-000000002102")


def _event(
    identifier: UUID,
    position: int,
    speaker: ConversationEventSpeaker,
    text: str,
) -> ConfirmedConversationEvent:
    return ConfirmedConversationEvent(
        id=identifier,
        position=position,
        event_type=ConversationEventType.TEXT_MESSAGE,
        speaker=speaker,
        text=text,
        timestamp=datetime(2026, 8, 6, 10, position, tzinfo=UTC),
        timestamp_is_estimated=False,
        raw_timestamp_text="private raw timestamp",
        source_image_index=9,
        source_region_id="private-source-region",
        ocr_confidence=1.0,
        classification_confidence=1.0,
        speaker_confidence=1.0,
        timestamp_confidence=1.0,
        relationship_confidence=None,
        requires_review=False,
        metadata={"private": PRIVATE_SENTINEL},
        deleted_at=None,
    )


def _context(
    first: str = PRIVATE_SENTINEL,
    second: str = "second reviewed synthetic message",
) -> OpenRouterConversationContextV1:
    return build_openrouter_context(
        (
            _event(_EVENT_A, 0, ConversationEventSpeaker.USER, first),
            _event(_EVENT_B, 1, ConversationEventSpeaker.OTHER, second),
        )
    )


def _output(
    event_ids: tuple[UUID, ...] = (_EVENT_A, _EVENT_B),
    *,
    drafts: bool = True,
    safety_notices: tuple[str, ...] = (),
) -> OpenRouterCoachOutputV1:
    return OpenRouterCoachOutputV1(
        summary="The exchange appears open, but the available context is limited.",
        observations=(
            OpenRouterObservationV1(
                heading="Clear exchange",
                observation="Both people contributed to the reviewed exchange.",
                uncertainty="Participation does not establish romantic interest.",
                alternative_interpretations=(
                    "The exchange may be friendly.",
                    "The exchange may be exploratory.",
                ),
                evidence_event_ids=event_ids,
            ),
        ),
        next_steps=("Ask an open question and leave room for a no.",),
        reply_drafts=(
            (
                OpenRouterReplyDraftV1(
                    text="I enjoyed chatting. Would you like to continue sometime?",
                    tone="warm and direct",
                    rationale="It expresses interest without pressure.",
                )
            ),
        )
        if drafts
        else (),
        safety_notices=safety_notices,
        limitations=("This is one possible interpretation, not a fact about intent.",),
    )


class _FakeCompletions:
    def __init__(self, content: str, *, finish_reason: str = "stop") -> None:
        self.content = content
        self.finish_reason = finish_reason
        self.arguments: dict[str, object] = {}
        self.call_count = 0

    async def create(self, **kwargs: object) -> SimpleNamespace:
        self.call_count += 1
        self.arguments = kwargs
        return SimpleNamespace(
            choices=[
                SimpleNamespace(
                    finish_reason=self.finish_reason,
                    message=SimpleNamespace(content=self.content, refusal=None),
                )
            ],
            usage=SimpleNamespace(prompt_tokens=120, completion_tokens=80, total_tokens=200),
        )


class _FakeOpenRouterClient:
    def __init__(self, content: str, *, finish_reason: str = "stop") -> None:
        self.completions = _FakeCompletions(content, finish_reason=finish_reason)
        self.chat = SimpleNamespace(completions=self.completions)


def _provider(client: _FakeOpenRouterClient) -> OpenRouterTieredProvider:
    return OpenRouterTieredProvider(
        api_key="test-key-that-is-never-sent-to-mobile",
        timeout_seconds=20,
        client=cast(Any, client),
    )


def test_adapter_enforces_schema_and_openrouter_privacy_routing() -> None:
    client = _FakeOpenRouterClient(_output().model_dump_json())

    result = asyncio.run(
        _provider(client).coach(
            _context(),
            model=OPENROUTER_PAID_MODEL,
            user_identifier="cc_pseudonymous",
            reasoning_effort="medium",
        )
    )

    assert result.usage == OpenRouterProviderUsageV1(120, 80, 200)
    arguments = client.completions.arguments
    assert arguments["model"] == OPENROUTER_PAID_MODEL
    assert arguments["user"] == "cc_pseudonymous"
    assert arguments["response_format"] == {
        "type": "json_schema",
        "json_schema": {
            "name": "convocoach_coaching_response",
            "strict": True,
            "schema": openrouter_coach_output_json_schema(),
        },
    }
    assert arguments["extra_body"] == {
        "provider": {
            "data_collection": "deny",
            "zdr": True,
            "require_parameters": True,
        },
        "reasoning": {"effort": "medium"},
    }
    assert "temperature" not in arguments
    messages = cast(tuple[dict[str, str], ...], arguments["messages"])
    serialized_input = messages[1]["content"]
    assert PRIVATE_SENTINEL in serialized_input
    for prohibited in (
        "source_image_index",
        "source_region_id",
        "raw_timestamp_text",
        "ocr_confidence",
        "metadata",
    ):
        assert prohibited not in serialized_input

    free_client = _FakeOpenRouterClient(_output().model_dump_json())
    asyncio.run(
        _provider(free_client).coach(
            _context(),
            model=OPENROUTER_FREE_MODEL,
            user_identifier="cc_pseudonymous",
            reasoning_effort=None,
        )
    )
    assert free_client.completions.arguments["temperature"] == 0.2
    assert free_client.completions.arguments["extra_body"] == {
        "provider": {
            "data_collection": "deny",
            "zdr": True,
            "require_parameters": True,
        }
    }


def test_strict_schema_requires_every_property_and_removes_defaults() -> None:
    schema = openrouter_coach_output_json_schema()

    def assert_strict_object_nodes(value: object) -> None:
        if isinstance(value, list):
            for item in value:
                assert_strict_object_nodes(item)
            return
        if not isinstance(value, dict):
            return
        assert "default" not in value
        properties = value.get("properties")
        if isinstance(properties, dict):
            assert value.get("additionalProperties") is False
            assert value.get("required") == list(properties)
        for item in value.values():
            assert_strict_object_nodes(item)

    assert_strict_object_nodes(schema)


def test_adapter_blocks_minors_before_network_and_rejects_unknown_evidence() -> None:
    blocked_client = _FakeOpenRouterClient(_output().model_dump_json())
    with pytest.raises(OpenRouterProviderFailure) as blocked:
        asyncio.run(
            _provider(blocked_client).coach(
                _context("I'm 17 and dating someone", "We kissed yesterday"),
                model=OPENROUTER_FREE_MODEL,
                user_identifier="cc_pseudonymous",
                reasoning_effort=None,
            )
        )
    assert blocked.value.code == OpenRouterProviderFailureCode.SAFETY_BLOCKED
    assert blocked_client.completions.call_count == 0

    unknown = UUID("00000000-0000-4000-8000-000000009999")
    invalid_client = _FakeOpenRouterClient(_output((unknown,)).model_dump_json())
    with pytest.raises(OpenRouterProviderFailure) as invalid:
        asyncio.run(
            _provider(invalid_client).coach(
                _context(),
                model=OPENROUTER_FREE_MODEL,
                user_identifier="cc_pseudonymous",
                reasoning_effort=None,
            )
        )
    assert invalid.value.code == OpenRouterProviderFailureCode.RESPONSE_INVALID


def test_configuration_and_model_specific_costs_are_fail_closed() -> None:
    incomplete = Settings(
        app_environment="test",
        ai_coaching_enabled=True,
        ai_provider_mode="openrouter_tiered",
    )
    with pytest.raises(SettingsValidationError) as failure:
        validate_settings(incomplete)
    assert set(failure.value.failures) >= {
        "openrouter_usage_enforcement_disabled",
        "openrouter_api_key_missing",
        "openrouter_user_identifier_secret_missing",
    }

    configured = replace(
        incomplete,
        ai_usage_enforcement_enabled=True,
        openrouter_api_key="phase-openrouter-test-value-that-must-remain-secret",
        openrouter_user_identifier_secret="s" * 32,
    )
    validate_settings(configured)
    repository = AIUsageRepository(
        cast(Any, SimpleNamespace()),
        usage_policy_from_settings(configured),
    )
    assert (
        repository.estimated_cost_microusd(
            input_tokens=4_000,
            output_tokens=800,
            model_identifier=OPENROUTER_FREE_MODEL,
        )
        == 1_080
    )
    assert (
        repository.estimated_cost_microusd(
            input_tokens=4_000,
            output_tokens=800,
            model_identifier=OPENROUTER_PAID_MODEL,
        )
        == 8_800
    )
    assert "phase-openrouter-test-value" not in repr(configured)
    assert "s" * 32 not in repr(configured)

    with pytest.raises(SettingsValidationError) as invalid_model:
        validate_settings(replace(configured, openrouter_free_model="https://unsafe.invalid"))
    assert "openrouter_free_model_invalid" in invalid_model.value.failures


class _FakeTieredProvider:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str | None]] = []

    @property
    def identifier(self) -> str:
        return OPENROUTER_PROVIDER_IDENTIFIER

    async def coach(
        self,
        context: OpenRouterConversationContextV1,
        *,
        model: str,
        user_identifier: str,
        reasoning_effort: str | None,
    ) -> OpenRouterProviderResultV1:
        self.calls.append((model, user_identifier, reasoning_effort))
        event_ids = tuple(message.event_id for message in context.messages)
        return OpenRouterProviderResultV1(
            response=_output(event_ids),
            usage=OpenRouterProviderUsageV1(100, 50, 150),
        )


def _create_reviewed_conversation(client: TestClient, headers: dict[str, str]) -> str:
    created = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Tiered synthetic", "other_participant_name": "Person"},
    )
    assert created.status_code == 201
    conversation_id = str(created.json()["id"])
    assert (
        client.post(
            "/api/v1/consents",
            headers=headers,
            json={
                "consent_type": "save_conversation_history",
                "granted": True,
                "policy_version": "openrouter-history-v1",
            },
        ).status_code
        == 201
    )
    assert (
        client.post(
            f"/api/v1/conversations/{conversation_id}/confirm",
            headers=headers,
            json={
                "title": "Reviewed tiered timeline",
                "source_type": "paste",
                "readiness_score": 100,
                "sources": [
                    {
                        "source_type": "paste",
                        "source_index": 0,
                        "mime_type": "text/plain",
                        "byte_size": None,
                        "storage_status": "not_stored",
                    }
                ],
                "messages": [
                    {
                        "speaker": "user",
                        "text": PRIVATE_SENTINEL,
                        "timestamp": "2026-08-06T10:00:00Z",
                        "visible_timestamp_text": "10:00",
                        "timestamp_estimated": False,
                        "ocr_confidence": None,
                        "source_screenshot_index": None,
                        "review_status": "added",
                    },
                    {
                        "speaker": "other",
                        "text": "second reviewed synthetic message",
                        "timestamp": "2026-08-06T10:01:00Z",
                        "visible_timestamp_text": "10:01",
                        "timestamp_estimated": False,
                        "ocr_confidence": None,
                        "source_screenshot_index": None,
                        "review_status": "added",
                    },
                ],
            },
        ).status_code
        == 200
    )
    assert (
        client.put(
            f"/api/v1/conversations/{conversation_id}/events",
            headers=headers,
            json={
                "schema_version": "conversation-events.v1",
                "events": [
                    {
                        "id": str(_EVENT_A),
                        "position": 0,
                        "event_type": "text_message",
                        "speaker": "user",
                        "text": PRIVATE_SENTINEL,
                        "timestamp": "2026-08-06T10:00:00Z",
                        "timestamp_is_estimated": False,
                        "raw_timestamp_text": None,
                        "source_image_index": None,
                        "source_region_id": None,
                        "ocr_confidence": None,
                        "classification_confidence": 1,
                        "speaker_confidence": 1,
                        "timestamp_confidence": 1,
                        "relationship_confidence": None,
                        "requires_review": False,
                        "metadata": {},
                        "deleted_at": None,
                    },
                    {
                        "id": str(_EVENT_B),
                        "position": 1,
                        "event_type": "text_message",
                        "speaker": "other",
                        "text": "second reviewed synthetic message",
                        "timestamp": "2026-08-06T10:01:00Z",
                        "timestamp_is_estimated": False,
                        "raw_timestamp_text": None,
                        "source_image_index": None,
                        "source_region_id": None,
                        "ocr_confidence": None,
                        "classification_confidence": 1,
                        "speaker_confidence": 1,
                        "timestamp_confidence": 1,
                        "relationship_confidence": None,
                        "requires_review": False,
                        "metadata": {},
                        "deleted_at": None,
                    },
                ],
                "relationships": [],
            },
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/consents",
            headers=headers,
            json={
                "consent_type": "external_ai_processing",
                "granted": True,
                "policy_version": "external-ai-processing-v3",
            },
        ).status_code
        == 201
    )
    return conversation_id


async def _grant_plus(application: FastAPI) -> None:
    session_factory = cast(SessionFactory, application.state.session_factory)
    async with session_factory() as session:
        user = await session.scalar(select(User).where(User.auth_subject == "subject-a"))
        assert user is not None
        now = datetime.now(UTC)
        session.add(
            SubscriptionEntitlement(
                user_id=user.id,
                plan_code="plus",
                status="active",
                storefront="admin",
                transaction_reference_hash="d" * 64,
                current_period_start=now - timedelta(days=1),
                current_period_end=now + timedelta(days=29),
            )
        )
        await session.commit()


def test_server_verified_plan_selects_free_then_paid_model(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    application = cast(FastAPI, coach_api_client.app)
    application.state.settings = replace(
        cast(Settings, application.state.settings),
        ai_provider_mode="openrouter_tiered",
        ai_mock_execution_enabled=False,
        ai_usage_enforcement_enabled=True,
        openrouter_api_key="phase-openrouter-test-value-that-must-remain-secret",
        openrouter_user_identifier_secret="s" * 32,
    )
    fake_provider = _FakeTieredProvider()
    monkeypatch.setattr(
        "app.services.conversation_coach.OpenRouterTieredProvider",
        lambda **_: fake_provider,
    )
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation_id}/coach-preview"

    welcome_response = coach_api_client.post(
        endpoint,
        headers={
            **auth_a,
            "Idempotency-Key": "00000000-0000-4000-8000-000000002191",
        },
    )
    assert welcome_response.status_code == 200
    assert welcome_response.json()["provenance"]["model"] == OPENROUTER_FREE_MODEL
    assert welcome_response.json()["allowance"]["plan_code"] == "welcome"
    assert fake_provider.calls[0][0] == OPENROUTER_FREE_MODEL
    assert fake_provider.calls[0][2] is None

    asyncio.run(_grant_plus(application))
    plus_response = coach_api_client.post(
        endpoint,
        headers={
            **auth_a,
            "Idempotency-Key": "00000000-0000-4000-8000-000000002192",
        },
    )
    assert plus_response.status_code == 200
    payload = cast(dict[str, Any], plus_response.json())
    assert payload["response_schema_version"] == "openrouter-coach-output.v1"
    assert payload["provenance"] == {
        "provider_identifier": OPENROUTER_PROVIDER_IDENTIFIER,
        "model": OPENROUTER_PAID_MODEL,
        "mock_execution": False,
        "response_stored_by_application": False,
    }
    assert payload["allowance"]["plan_code"] == "plus"
    assert fake_provider.calls[1][0] == OPENROUTER_PAID_MODEL
    assert fake_provider.calls[1][2] == "medium"
    assert fake_provider.calls[0][1].startswith("cc_")
    assert PRIVATE_SENTINEL not in str(payload)


def test_openrouter_user_identifier_is_stable_and_pseudonymous() -> None:
    owner = UUID("00000000-0000-4000-8000-000000002199")
    first = privacy_safe_openrouter_user_identifier(owner, "s" * 32)
    assert first == privacy_safe_openrouter_user_identifier(owner, "s" * 32)
    assert first != privacy_safe_openrouter_user_identifier(owner, "t" * 32)
    assert str(owner) not in first
