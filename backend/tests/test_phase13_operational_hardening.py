"""Phase 13 production-readiness and operational-hardening tests."""

import asyncio
import json
import logging
from dataclasses import dataclass, replace
from uuid import UUID

import pytest
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi.testclient import TestClient

from app.core.config import (
    Settings,
    SettingsValidationError,
    get_settings,
    validate_settings,
)
from app.core.lifecycle import (
    ApplicationLifecycleState,
    DatabaseReadinessStatus,
    MigrationCompatibilityStatus,
    OperationalReadinessSnapshot,
    OperationalStartupError,
    RedisReadinessStatus,
)
from app.core.observability import PrivacySafeJsonFormatter
from app.db.readiness import EXPECTED_DATABASE_REVISION
from app.db.session import create_database_engine, create_session_factory
from app.main import create_app

PRIVATE_SENTINEL = "phase-thirteen-private-request-material"
PRODUCTION_HOST = "api.example.invalid"


@dataclass
class StaticOperationalChecker:
    """Deterministic injected checker that performs no I/O or mutations."""

    snapshot: OperationalReadinessSnapshot
    calls: int = 0

    async def check(self) -> OperationalReadinessSnapshot:
        self.calls += 1
        return self.snapshot


def _ready_snapshot() -> OperationalReadinessSnapshot:
    return OperationalReadinessSnapshot(
        database=DatabaseReadinessStatus.READY,
        migrations=MigrationCompatibilityStatus.COMPATIBLE,
        redis=RedisReadinessStatus.READY,
    )


def _valid_production_settings() -> Settings:
    return Settings(
        app_environment="production",
        database_url=(
            "postgresql+asyncpg://service:deployment-secret@db.example.invalid/convocoach"
        ),
        redis_url="rediss://cache.example.invalid/0",
        redis_ca_certificate_path="/run/secrets/redis-ca.pem",
        development_auth_token="",
        development_auth_subject="",
        development_auth_email="",
        authentication_verifier_mode="production_contract",
        authentication_issuer="https://identity.example.invalid",
        authentication_audience="convocoach-api",
        authentication_jwks_url="https://identity.example.invalid/.well-known/jwks.json",
        ai_coaching_enabled=False,
        ai_mock_execution_enabled=False,
        openapi_enabled=False,
        operational_checks_enabled=True,
        allowed_hosts=(PRODUCTION_HOST,),
    )


def test_production_configuration_fails_closed_with_content_free_codes() -> None:
    settings = Settings(
        app_environment="production",
        database_url=f"postgresql+asyncpg://local:{PRIVATE_SENTINEL}@localhost/app",
        redis_url="redis://localhost/0",
        ai_coaching_enabled=True,
        ai_mock_execution_enabled=True,
    )

    with pytest.raises(SettingsValidationError) as captured:
        validate_settings(settings)

    assert {
        "production_openapi_enabled",
        "production_operational_checks_disabled",
        "production_database_unsafe",
        "production_redis_unsafe",
        "production_development_auth_configured",
        "production_mock_execution_enabled",
        "production_allowed_hosts_unsafe",
    }.issubset(captured.value.failures)
    assert PRIVATE_SENTINEL not in str(captured.value)
    assert PRIVATE_SENTINEL not in repr(captured.value)


def test_valid_production_configuration_is_accepted() -> None:
    validate_settings(_valid_production_settings())


def test_production_cloud_sql_socket_is_accepted_without_public_database_ip() -> None:
    settings = replace(
        _valid_production_settings(),
        database_url=(
            "postgresql+asyncpg://service:deployment-secret@/convocoach"
            "?host=%2Fcloudsql%2Fproject%3Aasia-south1%3Aproduction"
        ),
    )

    validate_settings(settings)


def test_production_store_can_use_google_workload_identity_without_json_key() -> None:
    settings = replace(
        _valid_production_settings(),
        store_billing_enabled=True,
        store_transaction_hash_secret="s" * 32,
        apple_iap_bundle_id="com.convocoach.convoCoach",
        apple_iap_app_id=123456789,
        apple_iap_environment="production",
        apple_iap_product_ids=(
            "com.convocoach.plus.monthly",
            "com.convocoach.plus.yearly",
        ),
        google_play_package_name="com.convocoach.convo_coach",
        google_play_product_ids=(
            "com.convocoach.plus.monthly",
            "com.convocoach.plus.yearly",
        ),
        google_play_use_application_default_credentials=True,
        google_play_service_account_json="",
        google_play_pubsub_audience=(
            "https://api.example.invalid/api/v1/subscription/notifications/google"
        ),
        google_play_pubsub_service_account=(
            "convocoach-play-push@example-project.iam.gserviceaccount.com"
        ),
    )

    validate_settings(settings)


def test_production_terra_requires_and_accepts_all_cost_and_privacy_controls() -> None:
    settings = replace(
        _valid_production_settings(),
        ai_coaching_enabled=True,
        ai_provider_mode="openai_terra",
        ai_external_processing_approved=True,
        ai_safety_evaluation_approved=True,
        ai_usage_enforcement_enabled=True,
        openai_api_key="production-test-key-that-is-never-logged",
        openai_safety_identifier_secret="s" * 32,
    )

    validate_settings(settings)


@pytest.mark.parametrize(
    ("processing_approved", "safety_approved", "failure"),
    [
        (
            False,
            True,
            "production_external_processing_unapproved",
        ),
        (
            True,
            False,
            "production_ai_safety_evaluation_unapproved",
        ),
    ],
)
def test_production_external_ai_requires_explicit_review_attestations(
    processing_approved: bool,
    safety_approved: bool,
    failure: str,
) -> None:
    settings = replace(
        _valid_production_settings(),
        ai_coaching_enabled=True,
        ai_provider_mode="zai_glm",
        ai_external_processing_approved=processing_approved,
        ai_safety_evaluation_approved=safety_approved,
        ai_usage_enforcement_enabled=True,
        zai_api_key="production-test-key-that-is-never-logged",
        zai_user_identifier_secret="s" * 32,
    )

    with pytest.raises(SettingsValidationError) as captured:
        validate_settings(settings)

    assert failure in captured.value.failures


@pytest.mark.parametrize(
    ("settings", "failure"),
    [
        (
            replace(
                _valid_production_settings(),
                database_url="postgresql+asyncpg:///convocoach",
            ),
            "production_database_unsafe",
        ),
        (
            replace(_valid_production_settings(), redis_url="rediss:///0"),
            "production_redis_unsafe",
        ),
        (
            replace(
                _valid_production_settings(),
                allowed_hosts=("*.example.invalid",),
            ),
            "allowed_hosts_invalid",
        ),
        (
            replace(
                _valid_production_settings(),
                app_environment=" Production ",
            ),
            "app_environment_not_normalized",
        ),
        (
            replace(_valid_production_settings(), log_level="info"),
            "log_level_not_normalized",
        ),
    ],
)
def test_production_rejects_ambiguous_network_configuration(
    settings: Settings,
    failure: str,
) -> None:
    with pytest.raises(SettingsValidationError) as captured:
        validate_settings(settings)

    assert failure in captured.value.failures


def test_invalid_environment_boolean_is_rejected(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENVIRONMENT", "test")
    monkeypatch.setenv("APP_DEBUG", "sometimes")
    get_settings.cache_clear()

    with pytest.raises(SettingsValidationError) as captured:
        get_settings()

    assert captured.value.failures == ("app_debug_invalid",)
    get_settings.cache_clear()


def test_mock_execution_requires_explicit_ai_execution_flag() -> None:
    settings = Settings(
        app_environment="test",
        ai_coaching_enabled=False,
        ai_mock_execution_enabled=True,
    )

    with pytest.raises(SettingsValidationError) as captured:
        validate_settings(settings)

    assert captured.value.failures == ("mock_requires_ai_execution",)


def test_successful_startup_records_readiness_and_shutdown_state() -> None:
    checker = StaticOperationalChecker(_ready_snapshot())
    application = create_app(
        _valid_production_settings(),
        readiness_checker=checker,
    )

    assert application.state.lifecycle == ApplicationLifecycleState.CREATED
    with TestClient(
        application,
        base_url=f"https://{PRODUCTION_HOST}",
    ) as client:
        assert application.state.lifecycle == ApplicationLifecycleState.READY
        response = client.get("/health/ready")
        assert response.status_code == 200
        assert response.json() == {
            "status": "ready",
            "checks": {
                "configuration": "valid",
                "lifecycle": "ready",
                "database": "ready",
                "migrations": "compatible",
                "redis": "ready",
            },
        }

    assert checker.calls == 1
    assert application.state.lifecycle == ApplicationLifecycleState.STOPPED


@pytest.mark.parametrize(
    "snapshot",
    [
        OperationalReadinessSnapshot(
            database=DatabaseReadinessStatus.NOT_READY,
            migrations=MigrationCompatibilityStatus.NOT_CHECKED,
            redis=RedisReadinessStatus.READY,
        ),
        OperationalReadinessSnapshot(
            database=DatabaseReadinessStatus.READY,
            migrations=MigrationCompatibilityStatus.INCOMPATIBLE,
            redis=RedisReadinessStatus.READY,
        ),
        OperationalReadinessSnapshot(
            database=DatabaseReadinessStatus.READY,
            migrations=MigrationCompatibilityStatus.COMPATIBLE,
            redis=RedisReadinessStatus.NOT_READY,
        ),
    ],
)
def test_production_startup_rejects_every_unready_dependency(
    snapshot: OperationalReadinessSnapshot,
) -> None:
    checker = StaticOperationalChecker(snapshot)
    application = create_app(
        _valid_production_settings(),
        readiness_checker=checker,
    )

    with (
        pytest.raises(OperationalStartupError),
        TestClient(
            application,
            base_url=f"https://{PRODUCTION_HOST}",
        ),
    ):
        pass

    assert checker.calls == 1
    assert application.state.lifecycle == ApplicationLifecycleState.STOPPED


def test_production_startup_rejects_missing_checker() -> None:
    engine = create_database_engine("sqlite+aiosqlite://")
    application = create_app(
        _valid_production_settings(),
        session_factory=create_session_factory(engine),
    )

    with (
        pytest.raises(OperationalStartupError),
        TestClient(
            application,
            base_url=f"https://{PRODUCTION_HOST}",
        ),
    ):
        pass

    asyncio.run(engine.dispose())


def test_liveness_does_not_claim_or_probe_dependency_readiness() -> None:
    checker = StaticOperationalChecker(
        OperationalReadinessSnapshot(
            database=DatabaseReadinessStatus.NOT_READY,
            migrations=MigrationCompatibilityStatus.NOT_CHECKED,
            redis=RedisReadinessStatus.NOT_READY,
        )
    )
    application = create_app(Settings(app_environment="test"), readiness_checker=checker)

    with TestClient(application) as client:
        response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert checker.calls == 0


def test_correlation_is_propagated_or_replaced_with_a_canonical_uuid() -> None:
    supplied = "00000000-0000-4000-8000-000000001313"
    with TestClient(create_app()) as client:
        accepted = client.get(
            "/health/live",
            headers={"X-Correlation-ID": supplied},
        )
        regenerated = client.get(
            "/health/live",
            headers={"X-Correlation-ID": PRIVATE_SENTINEL},
        )

    assert accepted.headers["x-correlation-id"] == supplied
    replacement = regenerated.headers["x-correlation-id"]
    assert replacement != PRIVATE_SENTINEL
    assert str(UUID(replacement)) == replacement


def test_structured_formatter_allows_only_content_free_fields() -> None:
    record = logging.LogRecord(
        name="test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg=PRIVATE_SENTINEL,
        args=(),
        exc_info=None,
    )
    record.event = "request_completed"
    record.correlation_id = "00000000-0000-4000-8000-000000001313"
    record.method = "POST"
    record.route = "/safe/{resource_id}"
    record.status_code = 200
    record.authorization = PRIVATE_SENTINEL
    record.request_body = PRIVATE_SENTINEL

    payload = PrivacySafeJsonFormatter().format(record)
    parsed = json.loads(payload)

    assert set(parsed) == {
        "timestamp",
        "level",
        "event",
        "correlation_id",
        "method",
        "route",
        "status_code",
    }
    assert PRIVATE_SENTINEL not in payload


def test_unhandled_errors_are_content_safe_and_receive_security_headers() -> None:
    application = create_app(Settings(app_environment="test"))

    @application.get("/phase13-explode")
    def explode() -> None:
        raise RuntimeError(PRIVATE_SENTINEL)

    with TestClient(application, raise_server_exceptions=False) as client:
        response = client.get("/phase13-explode")

    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_server_error"
    assert response.json()["error"]["correlation_id"] == response.headers["x-correlation-id"]
    assert PRIVATE_SENTINEL not in response.text
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["x-content-type-options"] == "nosniff"


def test_request_size_limit_rejects_before_route_processing() -> None:
    application = create_app(Settings(app_environment="test", max_request_body_bytes=16))
    with TestClient(application) as client:
        response = client.post("/missing", content="x" * 17)

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "request_too_large"
    assert response.json()["error"]["correlation_id"] == response.headers["x-correlation-id"]
    assert response.headers["cache-control"] == "no-store"


def test_security_headers_openapi_policy_and_trusted_hosts() -> None:
    checker = StaticOperationalChecker(_ready_snapshot())
    application = create_app(
        _valid_production_settings(),
        readiness_checker=checker,
    )
    with TestClient(
        application,
        base_url=f"https://{PRODUCTION_HOST}",
    ) as client:
        response = client.get("/")
        openapi = client.get("/openapi.json")
        docs = client.get("/docs")
        untrusted = client.get("/", headers={"Host": "untrusted.example.invalid"})

    assert response.status_code == 200
    assert response.json()["documentation"] == "disabled"
    assert response.headers["content-security-policy"].startswith("default-src 'none'")
    assert response.headers["permissions-policy"] == ("camera=(), geolocation=(), microphone=()")
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["strict-transport-security"].startswith("max-age=")
    assert openapi.status_code == 404
    assert docs.status_code == 404
    assert untrusted.status_code == 400
    assert "x-correlation-id" in untrusted.headers


def test_local_responses_do_not_emit_hsts() -> None:
    with TestClient(create_app()) as client:
        response = client.get("/")
        docs = client.get("/docs")

    assert "strict-transport-security" not in response.headers
    assert docs.status_code == 200
    assert "https://cdn.jsdelivr.net" in docs.headers["content-security-policy"]


def test_expected_database_revision_matches_alembic_head() -> None:
    script = ScriptDirectory.from_config(Config("alembic.ini"))

    assert script.get_current_head() == EXPECTED_DATABASE_REVISION
