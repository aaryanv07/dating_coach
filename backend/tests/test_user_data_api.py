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
            "age": 27,
            "gender": "Man",
            "profile_setup_completed": True,
            "relationship_intention": "exploring",
            "communication_tone": "thoughtful",
            "texting_style": "balanced",
            "preferred_message_length": "medium",
            "uses_emojis": True,
            "job_title": "Product designer",
            "likes": ["live music", "weekend hikes"],
            "looking_for": ["thoughtful conversation", "a serious relationship"],
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
    assert profile.json()["age"] == 27
    assert profile.json()["gender"] == "Man"
    assert profile.json()["profile_setup_completed"] is True
    assert profile.json()["job_title"] == "Product designer"
    assert profile.json()["likes"] == ["live music", "weekend hikes"]
    assert profile.json()["looking_for"] == [
        "thoughtful conversation",
        "a serious relationship",
    ]
    assert profile.json()["has_profile_photo"] is False
    assert consent.status_code == 201
    assert api_client.get("/api/v1/consents", headers=auth_a).json()[0]["granted"] is True

    other_profile = api_client.get("/api/v1/communication-profile", headers=auth_b)
    other_consents = api_client.get("/api/v1/consents", headers=auth_b)

    assert other_profile.status_code == 200
    assert other_profile.json()["preferred_name"] is None
    assert other_profile.json()["likes"] == []
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


def test_profile_rejects_underage_setup(api_client: TestClient, auth_a: dict[str, str]) -> None:
    response = api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={"age": 17, "profile_setup_completed": True},
    )

    assert response.status_code == 422


def test_profile_rejects_incomplete_completed_setup(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    response = api_client.patch(
        "/api/v1/communication-profile",
        headers=auth_a,
        json={"preferred_name": "Ari", "profile_setup_completed": True},
    )

    assert response.status_code == 422


def test_private_profile_photo_is_owner_scoped_and_removable(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    photo = b"\xff\xd8\xffsynthetic-private-image"

    stored = api_client.put(
        "/api/v1/communication-profile/photo",
        headers={**auth_a, "Content-Type": "image/jpeg"},
        content=photo,
    )

    assert stored.status_code == 204
    profile = api_client.get("/api/v1/communication-profile", headers=auth_a)
    assert profile.json()["has_profile_photo"] is True
    owned = api_client.get("/api/v1/communication-profile/photo", headers=auth_a)
    assert owned.status_code == 200
    assert owned.content == photo
    assert owned.headers["cache-control"] == "private, no-store"
    assert owned.headers["x-content-type-options"] == "nosniff"
    assert api_client.get("/api/v1/communication-profile/photo", headers=auth_b).status_code == 404

    removed = api_client.delete("/api/v1/communication-profile/photo", headers=auth_a)
    assert removed.status_code == 204
    assert api_client.get("/api/v1/communication-profile/photo", headers=auth_a).status_code == 404


def test_profile_photo_rejects_unsupported_or_excessive_content(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    unsupported = api_client.put(
        "/api/v1/communication-profile/photo",
        headers={**auth_a, "Content-Type": "image/svg+xml"},
        content=b"<svg/>",
    )
    oversized = api_client.put(
        "/api/v1/communication-profile/photo",
        headers={**auth_a, "Content-Type": "image/png"},
        content=b"\x89PNG\r\n\x1a\n" + b"x" * (900 * 1024),
    )
    disguised = api_client.put(
        "/api/v1/communication-profile/photo",
        headers={**auth_a, "Content-Type": "image/jpeg"},
        content=b"not-an-image",
    )

    assert unsupported.status_code == 415
    assert oversized.status_code == 413
    assert disguised.status_code == 422
