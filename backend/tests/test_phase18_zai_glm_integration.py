"""Phase 18 Z.ai GLM-5.2 adapter, safety, and vertical-slice tests."""

from __future__ import annotations

import asyncio
import json
from dataclasses import replace
from datetime import UTC, datetime
from types import SimpleNamespace
from typing import Any, cast
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.ai.zai_glm import (
    ZAI_GLM_PROVIDER_IDENTIFIER,
    GLMCoachOutputV1,
    GLMConversationContextV1,
    GLMObservationV1,
    GLMProviderFailure,
    GLMProviderFailureCode,
    GLMProviderResultV1,
    GLMProviderUsageV1,
    GLMReplyDraftV1,
    ZaiGLMProvider,
    build_glm_context,
    privacy_safe_user_identifier,
)
from app.core.config import ZAI_GLM_MODEL, Settings, SettingsValidationError, validate_settings
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConversationEventSpeaker,
    ConversationEventType,
)
from app.subscriptions.runtime import usage_policy_from_settings

PRIVATE_SENTINEL = "private synthetic glm conversation text"
_EVENT_A = UUID("00000000-0000-4000-8000-000000001801")
_EVENT_B = UUID("00000000-0000-4000-8000-000000001802")


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
        timestamp=datetime(2026, 7, 29, 10, position % 60, tzinfo=UTC),
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
) -> GLMConversationContextV1:
    return build_glm_context(
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
) -> GLMCoachOutputV1:
    return GLMCoachOutputV1(
        summary="The exchange appears open, but the available context is limited.",
        observations=(
            GLMObservationV1(
                heading="Clear exchange",
                observation="Both people contributed to the reviewed exchange.",
                uncertainty="Message participation does not establish romantic interest.",
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
                GLMReplyDraftV1(
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
    def __init__(
        self,
        content: str,
        *,
        finish_reason: str = "stop",
    ) -> None:
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
                    message=SimpleNamespace(content=self.content),
                )
            ],
            usage=SimpleNamespace(prompt_tokens=120, completion_tokens=80, total_tokens=200),
        )


class _FakeZaiClient:
    def __init__(self, content: str, *, finish_reason: str = "stop") -> None:
        self.completions = _FakeCompletions(content, finish_reason=finish_reason)
        self.chat = SimpleNamespace(completions=self.completions)


def _provider(client: _FakeZaiClient) -> ZaiGLMProvider:
    return ZaiGLMProvider(
        api_key="test-key-that-is-never-sent-to-mobile",
        timeout_seconds=20,
        client=cast(Any, client),
    )


def test_adapter_uses_zai_json_mode_and_minimized_context() -> None:
    client = _FakeZaiClient(_output().model_dump_json())
    provider = _provider(client)

    result = asyncio.run(provider.coach(_context(), user_identifier="cc_pseudonymous"))

    assert provider.identifier == ZAI_GLM_PROVIDER_IDENTIFIER
    assert result.response.summary.startswith("The exchange")
    assert result.usage == GLMProviderUsageV1(120, 80, 200)
    arguments = client.completions.arguments
    assert arguments["model"] == ZAI_GLM_MODEL
    assert arguments["response_format"] == {"type": "json_object"}
    assert arguments["max_tokens"] == 3_000
    assert cast(dict[str, object], arguments["extra_body"])["thinking"] == {"type": "enabled"}
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
    assert "output_schema" in json.loads(serialized_input)


def test_adapter_blocks_minor_scenario_before_provider_call() -> None:
    client = _FakeZaiClient(_output().model_dump_json())

    with pytest.raises(GLMProviderFailure) as failure:
        asyncio.run(
            _provider(client).coach(
                _context("I'm 17 and dating someone", "We kissed yesterday"),
                user_identifier="cc_pseudonymous",
            )
        )

    assert failure.value.code == GLMProviderFailureCode.SAFETY_BLOCKED
    assert client.completions.call_count == 0


def test_adapter_requires_safety_redirect_and_no_drafts_for_boundary_risk() -> None:
    unsafe_client = _FakeZaiClient(_output().model_dump_json())
    boundary_context = _context("Please leave me alone", "How do I keep texting them?")

    with pytest.raises(GLMProviderFailure) as failure:
        asyncio.run(
            _provider(unsafe_client).coach(
                boundary_context,
                user_identifier="cc_pseudonymous",
            )
        )

    assert failure.value.code == GLMProviderFailureCode.SAFETY_BLOCKED

    safe_output = _output(
        drafts=False,
        safety_notices=("Respect the stated boundary and do not contact them again.",),
    )
    safe_result = asyncio.run(
        _provider(_FakeZaiClient(safe_output.model_dump_json())).coach(
            boundary_context,
            user_identifier="cc_pseudonymous",
        )
    )
    assert safe_result.response.reply_drafts == ()
    assert safe_result.response.safety_notices


@pytest.mark.parametrize(
    ("content", "finish_reason", "expected"),
    [
        ("not json", "stop", GLMProviderFailureCode.RESPONSE_INVALID),
        (_output().model_dump_json(), "sensitive", GLMProviderFailureCode.PROVIDER_REFUSED),
        (_output().model_dump_json(), "length", GLMProviderFailureCode.RESPONSE_INVALID),
    ],
)
def test_adapter_fails_closed_on_invalid_or_refused_responses(
    content: str,
    finish_reason: str,
    expected: GLMProviderFailureCode,
) -> None:
    with pytest.raises(GLMProviderFailure) as failure:
        asyncio.run(
            _provider(_FakeZaiClient(content, finish_reason=finish_reason)).coach(
                _context(),
                user_identifier="cc_pseudonymous",
            )
        )

    assert failure.value.code == expected


def test_adapter_rejects_unknown_evidence_and_pseudonymizes_user() -> None:
    unknown = UUID("00000000-0000-4000-8000-000000009999")
    client = _FakeZaiClient(_output((unknown,)).model_dump_json())
    with pytest.raises(GLMProviderFailure) as failure:
        asyncio.run(_provider(client).coach(_context(), user_identifier="cc_pseudonymous"))
    assert failure.value.code == GLMProviderFailureCode.RESPONSE_INVALID

    owner = UUID("00000000-0000-4000-8000-000000001899")
    first = privacy_safe_user_identifier(owner, "s" * 32)
    assert first == privacy_safe_user_identifier(owner, "s" * 32)
    assert first != privacy_safe_user_identifier(owner, "t" * 32)
    assert str(owner) not in first


def test_glm_configuration_and_price_policy_are_fail_closed() -> None:
    incomplete = Settings(
        app_environment="test",
        ai_coaching_enabled=True,
        ai_provider_mode="zai_glm",
    )
    with pytest.raises(SettingsValidationError) as failure:
        validate_settings(incomplete)
    assert set(failure.value.failures) >= {
        "zai_usage_enforcement_disabled",
        "zai_api_key_missing",
        "zai_user_identifier_secret_missing",
    }

    configured = replace(
        incomplete,
        ai_usage_enforcement_enabled=True,
        zai_api_key="phase18-test-value-that-must-remain-secret",
        zai_user_identifier_secret="s" * 32,
        zai_input_price_microusd_per_million_tokens=1_234_567,
        zai_output_price_microusd_per_million_tokens=7_654_321,
    )
    validate_settings(configured)
    policy = usage_policy_from_settings(configured)
    assert policy.input_price_microusd_per_million_tokens == 1_234_567
    assert policy.output_price_microusd_per_million_tokens == 7_654_321
    assert "phase18-test-value" not in repr(configured)
    assert "s" * 32 not in repr(configured)


class _FakeGLMProvider:
    def __init__(self) -> None:
        self.calls: list[tuple[GLMConversationContextV1, str]] = []

    @property
    def identifier(self) -> str:
        return ZAI_GLM_PROVIDER_IDENTIFIER

    async def coach(
        self,
        context: GLMConversationContextV1,
        *,
        user_identifier: str,
    ) -> GLMProviderResultV1:
        self.calls.append((context, user_identifier))
        event_ids = tuple(message.event_id for message in context.messages)
        return GLMProviderResultV1(
            response=_output(event_ids),
            usage=GLMProviderUsageV1(100, 50, 150),
        )


def _create_reviewed_conversation(client: TestClient, headers: dict[str, str]) -> str:
    created = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "GLM synthetic", "other_participant_name": "Person"},
    )
    conversation_id = str(created.json()["id"])
    history_consent = client.post(
        "/api/v1/consents",
        headers=headers,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase18-history-v1",
        },
    )
    assert history_consent.status_code == 201
    confirmed = client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=headers,
        json={
            "title": "Reviewed GLM timeline",
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
                    "timestamp": "2026-07-29T10:00:00Z",
                    "visible_timestamp_text": "10:00",
                    "timestamp_estimated": False,
                    "ocr_confidence": None,
                    "source_screenshot_index": None,
                    "review_status": "added",
                },
                {
                    "speaker": "other",
                    "text": "second reviewed synthetic message",
                    "timestamp": "2026-07-29T10:01:00Z",
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
                    "timestamp": "2026-07-29T10:00:00Z",
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
                    "timestamp": "2026-07-29T10:01:00Z",
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


def test_api_requires_current_consent_and_returns_non_persistent_glm_output(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    application = cast(FastAPI, coach_api_client.app)
    application.state.settings = replace(
        cast(Settings, application.state.settings),
        ai_provider_mode="zai_glm",
        ai_mock_execution_enabled=False,
        ai_usage_enforcement_enabled=True,
        zai_api_key="phase18-test-value-that-must-remain-secret",
        zai_user_identifier_secret="s" * 32,
    )
    fake_provider = _FakeGLMProvider()
    monkeypatch.setattr(
        "app.services.conversation_coach.ZaiGLMProvider",
        lambda **_: fake_provider,
    )
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation_id}/coach-preview"
    coach_headers = {
        **auth_a,
        "Idempotency-Key": "00000000-0000-4000-8000-000000001899",
    }

    before_consent = coach_api_client.post(endpoint, headers=coach_headers)
    assert before_consent.status_code == 403
    assert before_consent.json()["error"]["code"] == "external_processing_consent_required"
    assert fake_provider.calls == []

    consent = coach_api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "external_ai_processing",
            "granted": True,
            "policy_version": "external-ai-processing-v3",
        },
    )
    assert consent.status_code == 201
    response = coach_api_client.post(endpoint, headers=coach_headers)

    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store, max-age=0"
    payload = cast(dict[str, Any], response.json())
    assert payload["response_schema_version"] == "glm-coach-output.v1"
    assert payload["provenance"] == {
        "provider_identifier": ZAI_GLM_PROVIDER_IDENTIFIER,
        "model": ZAI_GLM_MODEL,
        "mock_execution": False,
        "response_stored_by_application": False,
    }
    assert payload["allowance"]["consumed"] == 1
    assert len(fake_provider.calls) == 1
    _, user_identifier = fake_provider.calls[0]
    assert user_identifier.startswith("cc_")
    assert PRIVATE_SENTINEL not in str(payload)
