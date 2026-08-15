"""Phase 16 GPT-5.6 Terra provider and consented vertical-slice tests."""

from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any, cast
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.ai.openai_terra import (
    OPENAI_TERRA_PROVIDER_IDENTIFIER,
    OpenAITerraProvider,
    TerraCoachOutputV1,
    TerraConversationContextV1,
    TerraObservationV1,
    TerraProviderFailure,
    TerraProviderFailureCode,
    TerraProviderResultV1,
    TerraProviderUsageV1,
    TerraReplyDraftV1,
    build_terra_context,
    privacy_safe_safety_identifier,
)
from app.core.config import (
    OPENAI_TERRA_MODEL,
    Settings,
    SettingsValidationError,
    validate_settings,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConversationEventSpeaker,
    ConversationEventType,
)

PRIVATE_SENTINEL = "private synthetic terra conversation text"
_EVENT_A = UUID("00000000-0000-4000-8000-000000001601")
_EVENT_B = UUID("00000000-0000-4000-8000-000000001602")


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
        timestamp=datetime(2026, 7, 26, 10, position % 60, tzinfo=UTC),
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


def _context() -> TerraConversationContextV1:
    return build_terra_context(
        (
            _event(_EVENT_A, 0, ConversationEventSpeaker.USER, PRIVATE_SENTINEL),
            _event(
                _EVENT_B,
                1,
                ConversationEventSpeaker.OTHER,
                "second reviewed synthetic message",
            ),
        )
    )


def _output(event_ids: tuple[UUID, ...] = (_EVENT_A, _EVENT_B)) -> TerraCoachOutputV1:
    return TerraCoachOutputV1(
        summary="The exchange appears open, but the available context is limited.",
        observations=(
            TerraObservationV1(
                heading="Clear exchange",
                observation="Both people contributed to the reviewed exchange.",
                uncertainty="Message participation alone does not establish romantic interest.",
                alternative_interpretations=(
                    "The exchange may be friendly.",
                    "The exchange may be exploratory.",
                ),
                evidence_event_ids=event_ids,
            ),
        ),
        next_steps=("Ask an open question and leave room for a no.",),
        reply_drafts=(
            TerraReplyDraftV1(
                text="I enjoyed chatting. Would you like to continue sometime?",
                tone="warm and direct",
                rationale="It expresses interest without pressure.",
            ),
        ),
        safety_notices=(),
        limitations=("This is one possible interpretation, not a fact about intent.",),
    )


class _FakeResponses:
    def __init__(self, output: TerraCoachOutputV1) -> None:
        self.output = output
        self.arguments: dict[str, object] = {}

    async def parse(self, **kwargs: object) -> SimpleNamespace:
        self.arguments = kwargs
        return SimpleNamespace(
            output_parsed=self.output,
            usage=SimpleNamespace(input_tokens=120, output_tokens=80, total_tokens=200),
        )


class _FakeOpenAIClient:
    def __init__(self, output: TerraCoachOutputV1) -> None:
        self.responses = _FakeResponses(output)


def test_adapter_uses_terra_structured_responses_and_privacy_controls() -> None:
    client = _FakeOpenAIClient(_output())
    provider = OpenAITerraProvider(
        api_key="test-key-that-is-never-sent-to-mobile",
        timeout_seconds=20,
        client=cast(Any, client),
    )

    result = asyncio.run(provider.coach(_context(), safety_identifier="cc_pseudonymous"))

    assert provider.identifier == OPENAI_TERRA_PROVIDER_IDENTIFIER
    assert result.response.summary.startswith("The exchange")
    assert result.usage == TerraProviderUsageV1(120, 80, 200)
    arguments = client.responses.arguments
    assert arguments["model"] == OPENAI_TERRA_MODEL
    assert arguments["text_format"] is TerraCoachOutputV1
    assert arguments["reasoning"] == {"effort": "medium"}
    assert arguments["safety_identifier"] == "cc_pseudonymous"
    assert arguments["store"] is False
    assert arguments["max_output_tokens"] == 3_000
    serialized_input = cast(str, arguments["input"])
    assert PRIVATE_SENTINEL in serialized_input
    for prohibited in (
        "source_image_index",
        "source_region_id",
        "raw_timestamp_text",
        "ocr_confidence",
        "metadata",
    ):
        assert prohibited not in serialized_input


def test_adapter_rejects_evidence_not_present_in_sent_context() -> None:
    client = _FakeOpenAIClient(_output((UUID("00000000-0000-4000-8000-000000009999"),)))
    provider = OpenAITerraProvider(
        api_key="test-key-that-is-never-sent-to-mobile",
        timeout_seconds=20,
        client=cast(Any, client),
    )

    with pytest.raises(TerraProviderFailure) as failure:
        asyncio.run(provider.coach(_context(), safety_identifier="cc_pseudonymous"))

    assert failure.value.code == TerraProviderFailureCode.RESPONSE_INVALID


def test_context_is_bounded_and_safety_identifier_is_pseudonymous() -> None:
    events = tuple(
        _event(
            UUID(f"00000000-0000-4000-8000-{index:012d}"),
            index,
            ConversationEventSpeaker.USER if index % 2 == 0 else ConversationEventSpeaker.OTHER,
            "x" * 1_500,
        )
        for index in range(125)
    )

    context = build_terra_context(events)
    owner = UUID("00000000-0000-4000-8000-000000001699")
    first = privacy_safe_safety_identifier(owner, "s" * 32)

    assert len(context.messages) <= 120
    assert context.earlier_messages_omitted is True
    assert context.message_text_truncated is True
    assert all(len(message.text) <= 1_200 for message in context.messages)
    assert first == privacy_safe_safety_identifier(owner, "s" * 32)
    assert first != privacy_safe_safety_identifier(owner, "t" * 32)
    assert str(owner) not in first


def test_terra_configuration_is_fail_closed_and_secrets_are_not_repr_visible() -> None:
    incomplete = Settings(
        app_environment="test",
        ai_coaching_enabled=True,
        ai_provider_mode="openai_terra",
    )
    with pytest.raises(SettingsValidationError) as failure:
        validate_settings(incomplete)
    assert set(failure.value.failures) >= {
        "openai_api_key_missing",
        "openai_safety_identifier_secret_missing",
    }

    configured = replace(
        incomplete,
        ai_usage_enforcement_enabled=True,
        openai_api_key="phase16-test-value-that-must-remain-secret",
        openai_safety_identifier_secret="s" * 32,
    )
    validate_settings(configured)
    assert "phase16-test-value" not in repr(configured)
    assert "s" * 32 not in repr(configured)


class _FakeTerraProvider:
    def __init__(self) -> None:
        self.calls: list[tuple[TerraConversationContextV1, str]] = []

    @property
    def identifier(self) -> str:
        return OPENAI_TERRA_PROVIDER_IDENTIFIER

    async def coach(
        self,
        context: TerraConversationContextV1,
        *,
        safety_identifier: str,
    ) -> TerraProviderResultV1:
        self.calls.append((context, safety_identifier))
        event_ids = tuple(message.event_id for message in context.messages)
        return TerraProviderResultV1(
            response=_output(event_ids),
            usage=TerraProviderUsageV1(100, 50, 150),
        )


def _create_reviewed_conversation(client: TestClient, headers: dict[str, str]) -> str:
    created = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Terra synthetic", "other_participant_name": "Person"},
    )
    conversation_id = str(created.json()["id"])
    history_consent = client.post(
        "/api/v1/consents",
        headers=headers,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase16-history-v1",
        },
    )
    assert history_consent.status_code == 201
    confirmed = client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=headers,
        json={
            "title": "Reviewed Terra timeline",
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
                    "timestamp": "2026-07-26T10:00:00Z",
                    "visible_timestamp_text": "10:00",
                    "timestamp_estimated": False,
                    "ocr_confidence": None,
                    "source_screenshot_index": None,
                    "review_status": "added",
                },
                {
                    "speaker": "other",
                    "text": "second reviewed synthetic message",
                    "timestamp": "2026-07-26T10:01:00Z",
                    "visible_timestamp_text": "10:01",
                    "timestamp_estimated": False,
                    "ocr_confidence": None,
                    "source_screenshot_index": None,
                    "review_status": "added",
                },
            ],
        },
    )
    assert confirmed.status_code == 200
    events = client.put(
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
                    "timestamp": "2026-07-26T10:00:00Z",
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
                    "timestamp": "2026-07-26T10:01:00Z",
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
    )
    assert events.status_code == 200
    return conversation_id


def test_api_requires_external_consent_then_returns_non_persistent_terra_output(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    application = cast(FastAPI, coach_api_client.app)
    application.state.settings = replace(
        cast(Settings, application.state.settings),
        ai_provider_mode="openai_terra",
        ai_mock_execution_enabled=False,
        ai_usage_enforcement_enabled=True,
        openai_api_key="phase16-test-value-that-must-remain-secret",
        openai_safety_identifier_secret="s" * 32,
    )
    fake_provider = _FakeTerraProvider()
    monkeypatch.setattr(
        "app.services.conversation_coach.OpenAITerraProvider",
        lambda **_: fake_provider,
    )
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation_id}/coach-preview"
    coach_headers = {
        **auth_a,
        "Idempotency-Key": "00000000-0000-4000-8000-000000001699",
    }

    before_consent = coach_api_client.post(endpoint, headers=coach_headers)
    assert before_consent.status_code == 403
    assert before_consent.json()["error"]["code"] == "external_processing_consent_required"
    assert fake_provider.calls == []

    stale_external_consent = coach_api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "external_ai_processing",
            "granted": True,
            "policy_version": "external-ai-processing-v0",
        },
    )
    assert stale_external_consent.status_code == 201
    stale_response = coach_api_client.post(endpoint, headers=coach_headers)
    assert stale_response.status_code == 403
    assert stale_response.json()["error"]["code"] == ("external_processing_consent_required")
    assert fake_provider.calls == []

    external_consent = coach_api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "external_ai_processing",
            "granted": True,
            "policy_version": "external-ai-processing-v3",
        },
    )
    assert external_consent.status_code == 201
    response = coach_api_client.post(endpoint, headers=coach_headers)

    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store, max-age=0"
    payload = cast(dict[str, Any], response.json())
    assert payload["schema_version"] == "conversation-coach.v2"
    assert payload["summary"].startswith("The exchange")
    assert payload["provenance"] == {
        "provider_identifier": OPENAI_TERRA_PROVIDER_IDENTIFIER,
        "model": OPENAI_TERRA_MODEL,
        "mock_execution": False,
        "response_stored_by_application": False,
    }
    assert payload["usage"] == {
        "input_tokens": 100,
        "output_tokens": 50,
        "total_tokens": 150,
    }
    assert payload["allowance"] == {
        "schema_version": "coach-allowance.v1",
        "server_version": "subscription-runtime.v1",
        "plan_code": "welcome",
        "plan_status": "active",
        "allowance_kind": "conversation_analysis",
        "limit": 5,
        "consumed": 1,
        "reserved": 0,
        "remaining": 4,
        "reset_at": payload["allowance"]["reset_at"],
    }
    assert len(fake_provider.calls) == 1
    provider_context, safety_identifier = fake_provider.calls[0]
    assert [message.text for message in provider_context.messages] == [
        PRIVATE_SENTINEL,
        "second reviewed synthetic message",
    ]
    assert safety_identifier.startswith("cc_")
    assert PRIVATE_SENTINEL not in str(payload)
