"""Privacy-safe AI output reporting policy and ownership tests."""

from uuid import uuid4

from fastapi.testclient import TestClient


def _conversation(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post(
        "/api/v1/conversations",
        headers=headers,
        json={"title": "Synthetic report fixture"},
    )
    assert response.status_code == 201
    return response.json()["id"]


def test_report_is_owner_scoped_content_free_and_idempotent(
    api_client: TestClient,
    auth_a: dict[str, str],
    auth_b: dict[str, str],
) -> None:
    conversation_id = _conversation(api_client, auth_a)
    response_id = str(uuid4())
    payload = {
        "schema_version": "coach-output-report-request.v1",
        "response_id": response_id,
        "category": "harmful_or_unsafe",
    }

    created = api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-reports",
        headers=auth_a,
        json=payload,
    )
    replay = api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-reports",
        headers=auth_a,
        json=payload,
    )
    hidden = api_client.post(
        f"/api/v1/conversations/{conversation_id}/coach-reports",
        headers=auth_b,
        json=payload,
    )

    assert created.status_code == 201
    assert created.headers["cache-control"] == "no-store, max-age=0"
    assert set(created.json()) == {
        "schema_version",
        "report_id",
        "status",
        "created_at",
    }
    assert created.json()["status"] == "received"
    assert replay.status_code == 201
    assert replay.json()["report_id"] == created.json()["report_id"]
    assert hidden.status_code == 404

    exported = api_client.get("/api/v1/privacy/export", headers=auth_a)
    assert exported.status_code == 200
    reports = exported.json()["data"]["ai_output_reports"]
    assert reports[0]["response_id"] == response_id
    assert reports[0]["category"] == "harmful_or_unsafe"
    assert "content" not in reports[0]

    deleted = api_client.delete(f"/api/v1/conversations/{conversation_id}", headers=auth_a)
    assert deleted.status_code == 204
    after_deletion = api_client.get("/api/v1/privacy/export", headers=auth_a)
    assert after_deletion.status_code == 200
    assert after_deletion.json()["data"]["ai_output_reports"] == []


def test_report_rejects_unbounded_or_content_bearing_payloads(
    api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    conversation_id = _conversation(api_client, auth_a)
    endpoint = f"/api/v1/conversations/{conversation_id}/coach-reports"

    invalid_category = api_client.post(
        endpoint,
        headers=auth_a,
        json={
            "schema_version": "coach-output-report-request.v1",
            "response_id": str(uuid4()),
            "category": "free form user text",
        },
    )
    private_sentinel = "This must never be echoed by a validation response"
    content_bearing = api_client.post(
        endpoint,
        headers=auth_a,
        json={
            "schema_version": "coach-output-report-request.v1",
            "response_id": str(uuid4()),
            "category": "other",
            "generated_text": private_sentinel,
        },
    )

    assert invalid_category.status_code == 422
    assert content_bearing.status_code == 422
    assert content_bearing.json() == {"detail": "Invalid report"}
    assert private_sentinel not in content_bearing.text
    assert content_bearing.headers["cache-control"] == "no-store, max-age=0"
