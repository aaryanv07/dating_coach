"""Phase 11 secure mock-only Conversation Coach API tests."""

from copy import deepcopy
from dataclasses import replace
from typing import Any, cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.ai.execution_contracts import AIExecutionFailureCode
from app.core.config import Settings
from app.schemas.conversation_coach import CoachPreviewErrorCode
from app.services.conversation_coach import ConversationCoachPreviewService

PRIVATE_SENTINEL = "private synthetic phase eleven text"


def _create_reviewed_conversation(
    client: TestClient,
    headers: dict[str, str],
    *,
    requires_review: bool = False,
) -> str:
    created = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Phase 11 synthetic", "other_participant_name": "Person"},
    )
    conversation_id = str(created.json()["id"])
    consent = client.post(
        "/api/v1/consents",
        headers=headers,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase11-v1",
        },
    )
    assert consent.status_code == 201
    confirmed = client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=headers,
        json={
            "title": "Reviewed synthetic timeline",
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
                    "timestamp": "2026-07-25T10:00:00Z",
                    "visible_timestamp_text": "10:00",
                    "timestamp_estimated": False,
                    "ocr_confidence": None,
                    "source_screenshot_index": None,
                    "review_status": "added",
                },
                {
                    "speaker": "other",
                    "text": "second private synthetic line",
                    "timestamp": "2026-07-25T10:01:00Z",
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
                    "id": "00000000-0000-4000-8000-000000001101",
                    "position": 0,
                    "event_type": "text_message",
                    "speaker": "user",
                    "text": PRIVATE_SENTINEL,
                    "timestamp": "2026-07-25T10:00:00Z",
                    "timestamp_is_estimated": False,
                    "raw_timestamp_text": "private raw time",
                    "source_image_index": None,
                    "source_region_id": None,
                    "ocr_confidence": None,
                    "classification_confidence": 1,
                    "speaker_confidence": 1,
                    "timestamp_confidence": 1,
                    "relationship_confidence": None,
                    "requires_review": requires_review,
                    "metadata": {"private": PRIVATE_SENTINEL},
                    "deleted_at": None,
                },
                {
                    "id": "00000000-0000-4000-8000-000000001102",
                    "position": 1,
                    "event_type": "text_message",
                    "speaker": "other",
                    "text": "second private synthetic line",
                    "timestamp": "2026-07-25T10:01:00Z",
                    "timestamp_is_estimated": False,
                    "raw_timestamp_text": "private raw time",
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


def _assert_content_safe(payload: object) -> None:
    serialized = str(payload)
    assert PRIVATE_SENTINEL not in serialized
    assert "second private synthetic line" not in serialized
    assert "private raw time" not in serialized
    for prohibited in (
        "prompt",
        "screenshot",
        "ocr",
        "participant_name",
        "provider_response",
        "stack",
        "exception",
    ):
        assert prohibited not in serialized.casefold()


def test_preview_is_authenticated_owner_bound_and_content_free(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation_id}/coach-preview"
    detail_before = coach_api_client.get(
        f"/api/v1/conversations/{conversation_id}",
        headers=auth_a,
    ).json()
    events_before = coach_api_client.get(
        f"/api/v1/conversations/{conversation_id}/events",
        headers=auth_a,
    ).json()

    unauthenticated = coach_api_client.post(endpoint)
    hidden = coach_api_client.post(endpoint, headers=auth_b)
    correlated_headers = {
        **auth_a,
        "X-Correlation-ID": "00000000-0000-4000-8000-000000001113",
    }
    first = coach_api_client.post(endpoint, headers=correlated_headers)
    second = coach_api_client.post(endpoint, headers=correlated_headers)

    assert unauthenticated.status_code == 401
    assert unauthenticated.json()["error"]["code"] == "authentication_required"
    assert unauthenticated.headers["cache-control"] == "no-store, max-age=0"
    assert hidden.status_code == 404
    assert hidden.json()["error"]["code"] == "conversation_unavailable"
    assert first.status_code == 200
    assert first.json() == second.json()
    assert first.headers["cache-control"] == "no-store, max-age=0"
    assert first.headers["x-correlation-id"] == first.json()["correlation_id"]
    payload = cast(dict[str, Any], first.json())
    assert payload["schema_version"] == "conversation-coach-preview.v1"
    assert payload["execution_status"] == "completed"
    assert payload["provenance"] == {
        "provider_identifier": "mock-ai-provider.v1",
        "generator_identifier": "deterministic-coaching-response-mock.v1",
        "mock_execution": True,
    }
    assert [section["identifier"] for section in payload["sections"]] == [
        "supported_capabilities",
        "unavailable_capabilities",
        "explanations",
        "safety_notices",
    ]
    _assert_content_safe(payload)
    assert (
        coach_api_client.get(
            f"/api/v1/conversations/{conversation_id}",
            headers=auth_a,
        ).json()
        == detail_before
    )
    assert (
        coach_api_client.get(
            f"/api/v1/conversations/{conversation_id}/events",
            headers=auth_a,
        ).json()
        == events_before
    )


def test_default_flags_stop_before_pipeline_and_have_no_store_headers(
    api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    conversation_id = _create_reviewed_conversation(api_client, auth_a)

    response = api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-preview",
        headers=auth_a,
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "feature_disabled"
    assert response.headers["cache-control"] == "no-store, max-age=0"
    _assert_content_safe(response.json())


def test_preview_requires_consent_reviewed_persisted_events_and_no_body(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    draft = coach_api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "Draft", "other_participant_name": "Person"},
    ).json()["id"]
    no_consent = coach_api_client.post(
        f"/api/v1/conversations/{draft}/coach-preview",
        headers=auth_a,
    )
    assert no_consent.status_code == 403
    assert no_consent.json()["error"]["code"] == "consent_required"

    reviewed = _create_reviewed_conversation(coach_api_client, auth_a)
    unexpected_body = coach_api_client.post(
        f"/api/v1/conversations/{reviewed}/coach-preview",
        headers=auth_a,
        json={"provider": "external", "prompt": PRIVATE_SENTINEL},
    )
    assert unexpected_body.status_code == 422
    assert unexpected_body.json()["error"]["code"] == "schema_unsupported"
    _assert_content_safe(unexpected_body.json())

    invalid_path = coach_api_client.post(
        "/api/v1/conversations/not-a-uuid/coach-preview",
        headers=auth_a,
    )
    assert invalid_path.status_code == 422
    assert invalid_path.json()["error"]["code"] == "schema_unsupported"
    assert "not-a-uuid" not in str(invalid_path.json())


def test_mock_flag_is_independent_and_fails_closed(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    application = cast(FastAPI, coach_api_client.app)
    current = cast(Settings, application.state.settings)
    application.state.settings = replace(
        current,
        ai_mock_execution_enabled=False,
    )

    response = coach_api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-preview",
        headers=auth_a,
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "mock_disabled"
    _assert_content_safe(response.json())


def test_incomplete_review_is_distinct_and_never_executes(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    conversation_id = _create_reviewed_conversation(
        coach_api_client,
        auth_a,
        requires_review=True,
    )

    response = coach_api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-preview",
        headers=auth_a,
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "review_incomplete"
    _assert_content_safe(response.json())


def test_preview_contract_is_exact_and_openapi_documents_both_envelopes(
    coach_api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    conversation_id = _create_reviewed_conversation(coach_api_client, auth_a)
    payload = coach_api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-preview",
        headers=auth_a,
    ).json()
    assert set(payload) == {
        "schema_version",
        "execution_status",
        "response_schema_version",
        "renderer_schema_version",
        "response_id",
        "locale",
        "calculation_versions",
        "sections",
        "notices",
        "provenance",
        "correlation_id",
    }
    section = deepcopy(payload["sections"][0])
    assert set(section) == {
        "schema_version",
        "identifier",
        "heading_localization_key",
        "semantic_label_localization_key",
        "status",
        "item_localization_keys",
        "evidence_reference_count",
    }

    operation = coach_api_client.get("/openapi.json").json()["paths"][
        "/api/v1/conversations/{conversation_id}/coach-preview"
    ]["post"]
    assert operation["responses"]["200"]
    assert operation["responses"]["401"]
    assert operation["responses"]["503"]


@pytest.mark.parametrize(
    ("execution_code", "transport_code"),
    [
        (AIExecutionFailureCode.CANCELLED, CoachPreviewErrorCode.CANCELLED),
        (AIExecutionFailureCode.TIMED_OUT, CoachPreviewErrorCode.TIMED_OUT),
        (
            AIExecutionFailureCode.UNSUPPORTED_RESPONSE_VERSION,
            CoachPreviewErrorCode.CAPABILITY_UNSUPPORTED,
        ),
        (
            AIExecutionFailureCode.SAFETY_REJECTED,
            CoachPreviewErrorCode.SAFETY_REJECTED,
        ),
        (
            AIExecutionFailureCode.PROVIDER_UNAVAILABLE,
            CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
        ),
        (
            AIExecutionFailureCode.PROVIDER_FAILURE,
            CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
        ),
        (
            AIExecutionFailureCode.PROVIDER_RESPONSE_INVALID,
            CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
        ),
        (
            AIExecutionFailureCode.STRUCTURED_RESPONSE_PARSE_FAILURE,
            CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
        ),
        (
            AIExecutionFailureCode.RESPONSE_VALIDATION_FAILURE,
            CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
        ),
        (
            AIExecutionFailureCode.ANALYTICS_FAILURE,
            CoachPreviewErrorCode.INTERNAL_SAFE_FAILURE,
        ),
    ],
)
def test_execution_failures_have_stable_content_safe_transport_categories(
    execution_code: AIExecutionFailureCode,
    transport_code: CoachPreviewErrorCode,
) -> None:
    failure = ConversationCoachPreviewService._map_execution_failure(execution_code)

    assert failure.code == transport_code
    assert PRIVATE_SENTINEL not in repr(failure)
