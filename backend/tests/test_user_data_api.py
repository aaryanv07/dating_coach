"""User preference, communication profile, and consent integration tests."""

from fastapi.testclient import TestClient


def test_preferences_profile_and_consent_are_user_scoped(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    preferences = api_client.patch(
        "/api/v1/users/me/preferences",
        headers=auth_a,
        json={
            "preferred_language": "hinglish",
            "coaching_style": "gentle",
            "save_history": True,
        },
    )
    profile = api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={
            "preferred_name": "Ari",
            "relationship_intention": "exploring",
            "communication_tone": "thoughtful",
            "texting_style": "balanced",
            "preferred_message_length": "medium",
            "uses_emojis": True,
        },
    )
    consent = api_client.post(
        "/api/v1/consents",
        headers=auth_a,
        json={
            "consent_type": "save_conversation_history",
            "granted": True,
            "policy_version": "2026-07",
        },
    )

    assert preferences.status_code == 200
    assert preferences.json()["preferred_language"] == "hinglish"
    assert profile.status_code == 200
    assert profile.json()["preferred_name"] == "Ari"
    assert consent.status_code == 201
    assert api_client.get("/api/v1/consents", headers=auth_a).json()[0]["granted"] is True

    other_profile = api_client.get("/api/v1/communication-profile", headers=auth_b)
    other_consents = api_client.get("/api/v1/consents", headers=auth_b)

    assert other_profile.status_code == 200
    assert other_profile.json()["preferred_name"] is None
    assert other_consents.json() == []


def test_preference_and_profile_enums_reject_unknown_values(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    preference = api_client.patch(
        "/api/v1/users/me/preferences",
        headers=auth_a,
        json={"coaching_style": "manipulative"},
    )
    profile = api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={"relationship_intention": "guaranteed_outcome"},
    )

    assert preference.status_code == 422
    assert profile.status_code == 422
