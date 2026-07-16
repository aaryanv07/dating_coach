"""Phase 6A.1 event API tests using only synthetic conversation content."""

from copy import deepcopy
from typing import Any, cast

from fastapi.testclient import TestClient


def _create_conversation(client: TestClient, headers: dict[str, str]) -> dict[str, Any]:
    response = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Synthetic event review", "other_participant_name": "Morgan"},
    )
    assert response.status_code == 201
    return cast(dict[str, Any], response.json())


def _grant_history_consent(client: TestClient, headers: dict[str, str]) -> None:
    response = client.post(
        "/api/v1/consents",
        headers=headers,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "phase6a1-v1",
        },
    )
    assert response.status_code == 201


def _event_payload() -> dict[str, object]:
    return {
        "schema_version": "conversation-events.v1",
        "events": [
            {
                "id": "00000000-0000-4000-8000-000000000101",
                "position": 0,
                "event_type": "date_separator",
                "speaker": "system",
                "text": "Today",
                "timestamp": None,
                "timestamp_is_estimated": False,
                "raw_timestamp_text": "Today",
                "source_image_index": 0,
                "source_region_id": "synthetic-region-1",
                "ocr_confidence": 0.99,
                "classification_confidence": 0.98,
                "speaker_confidence": 1.0,
                "timestamp_confidence": None,
                "relationship_confidence": None,
                "requires_review": False,
                "metadata": {"provenance": "synthetic_fixture"},
                "deleted_at": None,
            },
            {
                "id": "00000000-0000-4000-8000-000000000102",
                "position": 1,
                "event_type": "text_message",
                "speaker": "user",
                "text": "Coffee this weekend?",
                "timestamp": "2026-07-18T09:30:00Z",
                "timestamp_is_estimated": False,
                "raw_timestamp_text": "9:30 AM",
                "source_image_index": 0,
                "source_region_id": "synthetic-region-2",
                "ocr_confidence": 0.97,
                "classification_confidence": 0.96,
                "speaker_confidence": 0.99,
                "timestamp_confidence": 0.94,
                "relationship_confidence": None,
                "requires_review": False,
                "metadata": {},
                "deleted_at": None,
            },
            {
                "id": "00000000-0000-4000-8000-000000000103",
                "position": 2,
                "event_type": "reaction",
                "speaker": "other",
                "text": None,
                "timestamp": None,
                "timestamp_is_estimated": False,
                "raw_timestamp_text": None,
                "source_image_index": 0,
                "source_region_id": "synthetic-region-3",
                "ocr_confidence": 0.95,
                "classification_confidence": 0.92,
                "speaker_confidence": 0.91,
                "timestamp_confidence": None,
                "relationship_confidence": 0.9,
                "requires_review": False,
                "metadata": {"reaction": "heart"},
                "deleted_at": None,
            },
        ],
        "relationships": [
            {
                "id": "00000000-0000-4000-8000-000000000201",
                "source_event_id": "00000000-0000-4000-8000-000000000103",
                "target_event_id": "00000000-0000-4000-8000-000000000102",
                "relationship_type": "reaction_target",
                "confidence": 0.9,
                "metadata": {},
            }
        ],
    }


def test_legacy_messages_have_explicit_read_time_event_projection(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation = _create_conversation(api_client, auth_a)
    participants = conversation["participants"]
    assert isinstance(participants, list)
    other = next(participant for participant in participants if participant["role"] == "other")
    created = api_client.post(
        f"/api/v1/conversations/{conversation['id']}/messages",
        headers=auth_a,
        json={"participant_id": other["id"], "body": "Synthetic legacy message"},
    )
    assert created.status_code == 201

    response = api_client.get(f"/api/v1/conversations/{conversation['id']}/events", headers=auth_a)

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == "conversation-events.v1"
    assert body["compatibility_mode"] == "message_projection"
    assert body["events"][0]["id"] == created.json()["id"]
    assert body["events"][0]["event_type"] == "text_message"
    assert body["events"][0]["metadata"] == {"provenance": "legacy_message_projection"}
    assert body["relationships"] == []


def test_event_sequence_is_owner_scoped_consent_gated_and_does_not_rewrite_messages(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    conversation = _create_conversation(api_client, auth_a)
    participants = conversation["participants"]
    assert isinstance(participants, list)
    user_participant = next(
        participant for participant in participants if participant["role"] == "user"
    )
    legacy = api_client.post(
        f"/api/v1/conversations/{conversation['id']}/messages",
        headers=auth_a,
        json={"participant_id": user_participant["id"], "body": "Keep this legacy row"},
    )
    assert legacy.status_code == 201

    hidden = api_client.put(
        f"/api/v1/conversations/{conversation['id']}/events",
        headers=auth_b,
        json=_event_payload(),
    )
    no_consent = api_client.put(
        f"/api/v1/conversations/{conversation['id']}/events",
        headers=auth_a,
        json=_event_payload(),
    )
    assert hidden.status_code == 404
    assert no_consent.status_code == 403

    _grant_history_consent(api_client, auth_a)
    saved = api_client.put(
        f"/api/v1/conversations/{conversation['id']}/events",
        headers=auth_a,
        json=_event_payload(),
    )

    assert saved.status_code == 200
    body = saved.json()
    assert body["compatibility_mode"] == "persisted_events"
    assert [event["event_type"] for event in body["events"]] == [
        "date_separator",
        "text_message",
        "reaction",
    ]
    assert body["relationships"][0]["relationship_type"] == "reaction_target"
    detail = api_client.get(f"/api/v1/conversations/{conversation['id']}", headers=auth_a).json()
    assert [message["body"] for message in detail["messages"]] == ["Keep this legacy row"]
    deleted = api_client.delete(f"/api/v1/conversations/{conversation['id']}", headers=auth_a)
    reopened = api_client.get(f"/api/v1/conversations/{conversation['id']}/events", headers=auth_a)
    assert deleted.status_code == 204
    assert reopened.status_code == 404


def test_event_sequence_validates_relationships_system_speaker_and_private_metadata(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    conversation = _create_conversation(api_client, auth_a)
    _grant_history_consent(api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation['id']}/events"

    missing_target = _event_payload()
    missing_target["relationships"] = []
    missing_response = api_client.put(endpoint, headers=auth_a, json=missing_target)

    wrong_system_speaker = deepcopy(_event_payload())
    events = wrong_system_speaker["events"]
    assert isinstance(events, list)
    events[0]["speaker"] = "other"
    speaker_response = api_client.put(endpoint, headers=auth_a, json=wrong_system_speaker)

    private_metadata = deepcopy(_event_payload())
    events = private_metadata["events"]
    assert isinstance(events, list)
    events[1]["metadata"] = {"screenshot_path": "/tmp/private.png"}
    metadata_response = api_client.put(endpoint, headers=auth_a, json=private_metadata)

    missing_relationship_confidence = deepcopy(_event_payload())
    relationships = missing_relationship_confidence["relationships"]
    assert isinstance(relationships, list)
    relationships[0]["confidence"] = None
    confidence_response = api_client.put(
        endpoint, headers=auth_a, json=missing_relationship_confidence
    )

    wrong_relationship_source = deepcopy(_event_payload())
    relationships = wrong_relationship_source["relationships"]
    assert isinstance(relationships, list)
    relationships[0]["source_event_id"] = "00000000-0000-4000-8000-000000000102"
    source_response = api_client.put(endpoint, headers=auth_a, json=wrong_relationship_source)

    assert missing_response.status_code == 422
    assert speaker_response.status_code == 422
    assert metadata_response.status_code == 422
    assert confidence_response.status_code == 422
    assert source_response.status_code == 422
