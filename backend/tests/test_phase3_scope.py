"""Phase 3 API boundary test."""

from fastapi.testclient import TestClient


def test_openapi_contains_only_phase_four_product_routes(client: TestClient) -> None:
    paths = set(client.get("/openapi.json").json()["paths"])

    assert paths == {
        "/health/live",
        "/health/ready",
        "/api/v1/auth/session/verify",
        "/api/v1/users/me",
        "/api/v1/users/me/preferences",
        "/api/v1/communication-profile",
        "/api/v1/consents",
        "/api/v1/conversations",
        "/api/v1/conversations/{conversation_id}",
        "/api/v1/conversations/{conversation_id}/messages",
        "/api/v1/conversations/{conversation_id}/confirm",
        "/api/v1/privacy/delete-account",
    }
