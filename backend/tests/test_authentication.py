"""Authentication-verifier unit and API contract tests."""

import pytest
from fastapi.testclient import TestClient

from app.auth.verifier import AuthenticationError, DevelopmentAuthenticationVerifier
from app.core.config import Settings


@pytest.mark.anyio
async def test_development_verifier_accepts_only_configured_token() -> None:
    verifier = DevelopmentAuthenticationVerifier(
        Settings(
            app_environment="test",
            development_auth_token="known-token",
            development_auth_subject="verified-subject",
        )
    )

    claims = await verifier.verify("known-token")

    assert claims.subject == "verified-subject"
    with pytest.raises(AuthenticationError):
        await verifier.verify("wrong-token")


def test_session_verification_requires_bearer_token(api_client: TestClient) -> None:
    response = api_client.post("/api/v1/auth/session/verify")

    assert response.status_code == 401
    assert response.json() == {"detail": "Authentication required"}


def test_verified_identity_provisions_same_server_user(
    api_client: TestClient, auth_a: dict[str, str]
) -> None:
    first = api_client.post("/api/v1/auth/session/verify", headers=auth_a)
    second = api_client.get("/api/v1/users/me", headers=auth_a)

    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    assert second.json()["email"] == "a@example.invalid"
    assert "auth_subject" not in second.json()
