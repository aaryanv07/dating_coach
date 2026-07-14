"""Health endpoint contract tests."""

from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_liveness_reports_service(client: TestClient) -> None:
    response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "ConvoCoach API",
        "version": "0.1.0",
    }


def test_readiness_reports_configured_dependencies(client: TestClient) -> None:
    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "checks": {"database": "configured", "redis": "configured"},
    }


def test_readiness_fails_closed_without_required_urls() -> None:
    settings = Settings(database_url="", redis_url="")

    with TestClient(create_app(settings)) as client:
        response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.json() == {
        "status": "not_ready",
        "checks": {"database": "missing", "redis": "missing"},
    }


def test_service_index_does_not_expose_configuration(client: TestClient) -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {
        "service": "ConvoCoach API",
        "version": "0.1.0",
        "documentation": "/docs",
    }
