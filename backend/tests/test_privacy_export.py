"""Authenticated, owner-scoped, content-safe account export tests."""

import json

from fastapi.testclient import TestClient


def test_account_export_is_owner_scoped_portable_and_non_cacheable(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={
            "preferred_name": "Synthetic owner",
            "age": 31,
            "gender": "Non-binary",
            "profile_setup_completed": True,
            "communication_tone": "calm",
            "job_title": "Synthetic role",
            "likes": ["books"],
            "looking_for": ["kind communication"],
        },
    )
    consent = api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "export-test-v1",
        },
    )
    assert consent.status_code == 201
    owned = api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "Owned synthetic conversation"},
    )
    foreign = api_client.post(
        "/api/v1/conversations",
        headers=auth_b,
        json={"title": "Foreign synthetic conversation"},
    )
    assert owned.status_code == 201
    assert foreign.status_code == 201
    participant_id = next(
        participant["id"]
        for participant in owned.json()["participants"]
        if participant["role"] == "user"
    )
    message = api_client.post(
        f"/api/v1/conversations/{owned.json()['id']}/messages",
        headers=auth_a,
        json={
            "participant_id": participant_id,
            "body": "Owner-controlled synthetic export text",
        },
    )
    assert message.status_code == 201

    response = api_client.get("/api/v1/privacy/export", headers=auth_a)

    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store, max-age=0"
    assert response.headers["content-disposition"] == (
        'attachment; filename="convocoach-account-export.json"'
    )
    body = response.json()
    assert body["schema_version"] == "account-export.v1"
    assert body["data"]["communication_profile"]["preferred_name"] == "Synthetic owner"
    assert body["data"]["communication_profile"]["age"] == 31
    assert body["data"]["communication_profile"]["gender"] == "Non-binary"
    assert body["data"]["communication_profile"]["job_title"] == "Synthetic role"
    assert body["data"]["communication_profile"]["likes"] == ["books"]
    assert body["data"]["consents"][0]["policy_version"] == "export-test-v1"
    exported = json.dumps(body)
    assert "Owned synthetic conversation" in exported
    assert "Owner-controlled synthetic export text" in exported
    assert "Foreign synthetic conversation" not in exported
    for prohibited in (
        "auth_subject",
        "transaction_reference_hash",
        "request_fingerprint",
        "idempotency_key",
        "correlation_id",
        "screenshot_bytes",
        "screenshot_path",
        "raw_prompt",
    ):
        assert prohibited not in exported


def test_account_export_requires_authentication(api_client: TestClient) -> None:
    response = api_client.get("/api/v1/privacy/export")

    assert response.status_code == 401
