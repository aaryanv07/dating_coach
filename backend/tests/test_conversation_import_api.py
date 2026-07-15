"""Confirmed conversation import integration tests using synthetic content."""

from fastapi.testclient import TestClient


def _create_conversation(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Synthetic import", "other_participant_name": "Taylor"},
    )
    assert response.status_code == 201
    return str(response.json()["id"])


def _grant_history_consent(client: TestClient, headers: dict[str, str]) -> None:
    response = client.post(
        "/api/v1/consents",
        headers=headers,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase4-v1",
        },
    )
    assert response.status_code == 201


def _confirmed_payload() -> dict[str, object]:
    return {
        "title": "Reviewed synthetic chat",
        "source_type": "screenshot",
        "readiness_score": 94,
        "extraction_metadata": {
            "provider": "google_ml_kit_on_device",
            "provider_version": "text-recognition-v2/plugin-0.16.0",
            "extraction_version": "conversation-extraction-v1",
            "preprocessing_version": "image-v1",
            "confidence_available": True,
        },
        "sources": [
            {
                "source_type": "screenshot",
                "source_index": 0,
                "mime_type": "image/png",
                "byte_size": 2048,
                "storage_status": "deleted",
            }
        ],
        "messages": [
            {
                "speaker": "other",
                "text": "Are we still on for Saturday?",
                "timestamp": "2026-07-18T09:30:00Z",
                "visible_timestamp_text": "9:30 AM",
                "timestamp_estimated": False,
                "ocr_confidence": 0.98,
                "source_screenshot_index": 0,
                "review_status": "extracted",
            },
            {
                "speaker": "user",
                "text": "Yes, noon works for me.",
                "timestamp": None,
                "visible_timestamp_text": "9:31 AM",
                "timestamp_estimated": False,
                "ocr_confidence": 0.76,
                "source_screenshot_index": 0,
                "review_status": "edited",
            },
        ],
    }


def test_confirmation_requires_active_history_consent(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)

    response = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=_confirmed_payload(),
    )

    assert response.status_code == 403
    detail = api_client.get(f"/api/v1/conversations/{conversation_id}", headers=auth_a).json()
    assert detail["status"] == "draft"
    assert detail["messages"] == []


def test_confirmed_import_is_normalized_owned_and_reopenable(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)

    confirmed = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=_confirmed_payload(),
    )

    assert confirmed.status_code == 200
    body = confirmed.json()
    assert body["status"] == "confirmed"
    assert body["source_type"] == "screenshot"
    assert body["readiness_score"] == 94
    assert body["extraction_metadata"] == _confirmed_payload()["extraction_metadata"]
    assert [message["position"] for message in body["messages"]] == [0, 1]
    assert [message["speaker"] for message in body["messages"]] == ["other", "user"]
    assert all(message["status"] == "confirmed" for message in body["messages"])
    assert body["messages"][1]["sent_at"] is None
    assert body["messages"][1]["visible_timestamp_text"] == "9:31 AM"
    assert body["sources"][0]["storage_status"] == "deleted"
    assert body["sources"][0]["deleted_at"] is not None
    assert "path" not in body["sources"][0]
    assert "content" not in body["sources"][0]

    reopened = api_client.get(f"/api/v1/conversations/{conversation_id}", headers=auth_a)
    hidden = api_client.get(f"/api/v1/conversations/{conversation_id}", headers=auth_b)

    assert reopened.status_code == 200
    assert [
        (message["id"], message["speaker"], message["body"])
        for message in reopened.json()["messages"]
    ] == [(message["id"], message["speaker"], message["body"]) for message in body["messages"]]
    assert hidden.status_code == 404


def test_confirmation_validates_readiness_and_source_disposal(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)
    payload = _confirmed_payload()
    payload["readiness_score"] = 84

    low_readiness = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    payload = _confirmed_payload()
    sources = payload["sources"]
    assert isinstance(sources, list)
    sources[0]["storage_status"] = "not_stored"
    retained_source = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    assert low_readiness.status_code == 422
    assert retained_source.status_code == 422


def test_confirmation_rejects_unresolved_low_confidence_ocr(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)
    payload = _confirmed_payload()
    messages = payload["messages"]
    assert isinstance(messages, list)
    messages[1]["review_status"] = "extracted"

    response = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    assert response.status_code == 422


def test_screenshot_confirmation_requires_content_free_extraction_metadata(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)
    payload = _confirmed_payload()
    payload.pop("extraction_metadata")

    missing = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    payload = _confirmed_payload()
    metadata = payload["extraction_metadata"]
    assert isinstance(metadata, dict)
    metadata["screenshot_bytes"] = "not-allowed"
    raw_content = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    assert missing.status_code == 422
    assert raw_content.status_code == 422


def test_confirmation_rejects_estimated_timestamps_and_raw_source_fields(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation_id = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)
    payload = _confirmed_payload()
    messages = payload["messages"]
    assert isinstance(messages, list)
    messages[0]["timestamp_estimated"] = True
    estimated = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    payload = _confirmed_payload()
    sources = payload["sources"]
    assert isinstance(sources, list)
    sources[0]["screenshot_bytes"] = "not-allowed"
    raw_source = api_client.post(
        f"/api/v1/conversations/{conversation_id}/confirm",
        headers=auth_a,
        json=payload,
    )

    assert estimated.status_code == 422
    assert raw_source.status_code == 422
