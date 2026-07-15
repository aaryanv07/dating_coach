"""Conversation ownership, message, and deletion integration tests."""

from fastapi.testclient import TestClient


def test_conversation_lifecycle_enforces_ownership(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    created = api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "Synthetic conversation", "other_participant_name": "Sam"},
    )

    assert created.status_code == 201
    conversation = created.json()
    conversation_id = conversation["id"]
    other = next(
        participant
        for participant in conversation["participants"]
        if participant["role"] == "other"
    )

    message = api_client.post(
        f"/api/v1/conversations/{conversation_id}/messages",
        headers=auth_a,
        json={"participant_id": other["id"], "body": "A synthetic hello."},
    )
    listing = api_client.get("/api/v1/conversations", headers=auth_a)

    assert message.status_code == 201
    assert listing.status_code == 200
    assert listing.json()[0]["message_count"] == 1
    assert "body" not in listing.json()[0]

    assert (
        api_client.get(f"/api/v1/conversations/{conversation_id}", headers=auth_b).status_code
        == 404
    )
    assert (
        api_client.delete(f"/api/v1/conversations/{conversation_id}", headers=auth_b).status_code
        == 404
    )

    deleted = api_client.delete(f"/api/v1/conversations/{conversation_id}", headers=auth_a)

    assert deleted.status_code == 204
    assert (
        api_client.get(f"/api/v1/conversations/{conversation_id}", headers=auth_a).status_code
        == 404
    )


def test_message_requires_participant_from_owned_conversation(
    api_client: TestClient, auth_a: dict[str, str], auth_b: dict[str, str]
) -> None:
    first = api_client.post(
        "/api/v1/conversations",
        headers=auth_a,
        json={"title": "First", "other_participant_name": "One"},
    ).json()
    second = api_client.post(
        "/api/v1/conversations",
        headers=auth_b,
        json={"title": "Second", "other_participant_name": "Two"},
    ).json()

    response = api_client.post(
        f"/api/v1/conversations/{first['id']}/messages",
        headers=auth_a,
        json={
            "participant_id": second["participants"][0]["id"],
            "body": "Synthetic content.",
        },
    )

    assert response.status_code == 404
