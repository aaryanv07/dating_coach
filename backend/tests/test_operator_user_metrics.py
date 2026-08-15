"""Privacy and authorization tests for aggregate operator user metrics."""

import asyncio
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncEngine

from app.auth.contracts import AuthClaims
from app.auth.verifier import StaticAuthenticationVerifier
from app.core.config import Settings
from app.db.base import Base
from app.db.models import AIUsageRecord, SubscriptionEntitlement, User
from app.db.session import create_database_engine, create_session_factory
from app.main import create_app
from app.repositories.user_metrics import UserMetricsRepository

NOW = datetime(2026, 8, 8, 12, 0, tzinfo=UTC)


async def _create_schema(engine: AsyncEngine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


@pytest.fixture
def operator_client(tmp_path: Path) -> Iterator[TestClient]:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'operator.db'}"
    engine = create_database_engine(database_url)
    asyncio.run(_create_schema(engine))
    verifier = StaticAuthenticationVerifier(
        {
            "ordinary-token": AuthClaims(subject="ordinary-subject"),
            "operator-token": AuthClaims(
                subject="operator-subject",
                permissions=("read:user-metrics",),
            ),
            "second-token": AuthClaims(subject="second-subject"),
        }
    )
    application = create_app(
        Settings(app_environment="test", database_url=database_url),
        session_factory=create_session_factory(engine),
        auth_verifier=verifier,
    )
    with TestClient(application) as test_client:
        yield test_client
    asyncio.run(engine.dispose())


def test_user_metrics_requires_explicit_operator_permission(
    operator_client: TestClient,
) -> None:
    missing = operator_client.get("/api/v1/admin/user-metrics")
    ordinary = operator_client.get(
        "/api/v1/admin/user-metrics",
        headers={"Authorization": "Bearer ordinary-token"},
    )

    assert missing.status_code == 401
    assert ordinary.status_code == 403
    assert ordinary.json() == {"detail": "Insufficient operator permission"}


def test_user_metrics_response_is_aggregate_content_free(operator_client: TestClient) -> None:
    for token in ("ordinary-token", "second-token"):
        response = operator_client.post(
            "/api/v1/auth/session/verify",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200

    response = operator_client.get(
        "/api/v1/admin/user-metrics",
        headers={"Authorization": "Bearer operator-token"},
    )

    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store, max-age=0"
    body = response.json()
    assert body["schema_version"] == "user-metrics.v1"
    assert body["total_registered_accounts"] == 2
    assert body["active_accounts"] == 2
    assert body["deleted_accounts"] == 0
    assert body["free_active_accounts"] == 2
    assert not {
        "email",
        "auth_subject",
        "users",
        "messages",
        "prompts",
        "screenshots",
    }.intersection(body)


@pytest.mark.anyio
async def test_user_metrics_repository_counts_plans_and_completed_ai_activity(
    tmp_path: Path,
) -> None:
    engine = create_database_engine(f"sqlite+aiosqlite:///{tmp_path / 'metrics.db'}")
    session_factory = create_session_factory(engine)
    await _create_schema(engine)
    active_paid = User(auth_subject="active-paid", created_at=NOW - timedelta(days=2))
    active_free = User(auth_subject="active-free", created_at=NOW - timedelta(days=20))
    deleted = User(
        auth_subject="deleted",
        created_at=NOW - timedelta(days=1),
        deleted_at=NOW - timedelta(hours=1),
    )
    try:
        async with session_factory() as session:
            session.add_all((active_paid, active_free, deleted))
            await session.flush()
            session.add_all(
                (
                    SubscriptionEntitlement(
                        user_id=active_paid.id,
                        plan_code="plus",
                        status="active",
                        storefront="admin",
                        transaction_reference_hash="a" * 64,
                        current_period_start=NOW - timedelta(days=5),
                        current_period_end=NOW + timedelta(days=25),
                    ),
                    SubscriptionEntitlement(
                        user_id=deleted.id,
                        plan_code="plus",
                        status="active",
                        storefront="admin",
                        transaction_reference_hash="b" * 64,
                        current_period_start=NOW - timedelta(days=5),
                        current_period_end=NOW + timedelta(days=25),
                    ),
                    AIUsageRecord(
                        user_id=active_paid.id,
                        allowance_kind="conversation_analysis",
                        idempotency_key="paid-completed",
                        request_fingerprint="c" * 64,
                        status="completed",
                        plan_code="plus",
                        window_start=NOW - timedelta(days=1),
                        window_end=NOW + timedelta(days=29),
                        model_identifier="test-model",
                        correlation_id=uuid4(),
                        completed_at=NOW - timedelta(hours=2),
                    ),
                    AIUsageRecord(
                        user_id=active_free.id,
                        allowance_kind="reply_generation",
                        idempotency_key="free-reserved",
                        request_fingerprint="d" * 64,
                        status="reserved",
                        plan_code="free",
                        window_start=NOW - timedelta(days=1),
                        window_end=NOW + timedelta(days=29),
                        model_identifier="test-model",
                        correlation_id=uuid4(),
                    ),
                    AIUsageRecord(
                        user_id=deleted.id,
                        allowance_kind="reply_generation",
                        idempotency_key="deleted-completed",
                        request_fingerprint="e" * 64,
                        status="completed",
                        plan_code="plus",
                        window_start=NOW - timedelta(days=1),
                        window_end=NOW + timedelta(days=29),
                        model_identifier="test-model",
                        correlation_id=uuid4(),
                        completed_at=NOW - timedelta(hours=2),
                    ),
                )
            )
            await session.commit()

            snapshot = await UserMetricsRepository(session).snapshot(evaluated_at=NOW)

            assert snapshot.total_registered_accounts == 3
            assert snapshot.active_accounts == 2
            assert snapshot.deleted_accounts == 1
            assert snapshot.new_registered_accounts_7d == 2
            assert snapshot.new_registered_accounts_30d == 3
            assert snapshot.paid_active_accounts == 1
            assert snapshot.free_active_accounts == 1
            assert snapshot.ai_active_accounts_24h == 1
            assert snapshot.ai_active_accounts_7d == 1
            assert snapshot.ai_active_accounts_30d == 1
    finally:
        await engine.dispose()
