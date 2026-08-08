"""Phase 14 identity and release-candidate qualification tests."""

from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.ai.provider_registry import build_default_provider_registry
from app.auth.contracts import (
    LOCAL_AUTH_AUDIENCE,
    LOCAL_AUTH_ISSUER,
    AuthClaims,
    AuthClaimValidationError,
)
from app.auth.policy import ProductionVerifierPolicy, ProductionVerifierPolicyError
from app.auth.verifier import (
    AuthenticationError,
    ProductionAuthenticationVerifier,
    build_authentication_verifier,
)
from app.core.config import Settings, SettingsValidationError, validate_settings
from app.db.base import Base
from app.db.session import create_database_engine, create_session_factory
from app.release.contracts import (
    ArtifactPlatform,
    GateStatus,
    ReleaseArtifactProvenanceV1,
    ReleaseCandidateManifestV1,
    ReleaseGateEvidenceV1,
    ReleaseGateId,
    SupplyChainComponentEvidenceV1,
)
from app.release.evidence import (
    EvidenceCollectionError,
    collect_artifact_provenance,
    collect_supply_chain_component,
)
from app.release.gates import REQUIRED_RELEASE_GATES, ReleaseGateEvaluator
from app.repositories.users import UserRepository

REVISION = "a" * 40
DIGEST = "b" * 64
NOW = datetime(2026, 7, 25, 10, 0, tzinfo=UTC)


def production_settings() -> Settings:
    return Settings(
        app_environment="production",
        database_url="postgresql+asyncpg://service:secret@db.example.invalid/app",
        redis_url="rediss://cache.example.invalid/0",
        redis_ca_certificate_path="/run/secrets/redis-ca.pem",
        development_auth_token="",
        development_auth_subject="",
        development_auth_email="",
        authentication_verifier_mode="production_contract",
        authentication_issuer="https://identity.example.invalid",
        authentication_audience="convocoach-api",
        authentication_jwks_url="https://identity.example.invalid/keys.json",
        authentication_allowed_algorithms=("ES256", "RS256"),
        openapi_enabled=False,
        operational_checks_enabled=True,
        allowed_hosts=("api.example.invalid",),
    )


def passing_gate(gate_id: ReleaseGateId) -> ReleaseGateEvidenceV1:
    return ReleaseGateEvidenceV1(
        gate_id=gate_id,
        status=GateStatus.PASS,
        evidence_ids=(f"{gate_id.value}.evidence",),
    )


def complete_manifest() -> ReleaseCandidateManifestV1:
    return ReleaseCandidateManifestV1(
        candidate_id="phase14-test-candidate",
        application_version="0.2.0-1",
        generated_at=NOW,
        source_revision=REVISION,
        source_worktree_clean=True,
        source_matches_revision=True,
        environment="production",
        authentication_verifier_mode="production_contract",
        production_authentication_available=True,
        ai_execution_enabled=False,
        mock_execution_enabled=False,
        phase6a3_status=GateStatus.PASS,
        artifacts=(
            ReleaseArtifactProvenanceV1(
                artifact_id="android-release-aab",
                platform=ArtifactPlatform.ANDROID,
                media_type="application.android-aab",
                sha256=DIGEST,
                size_bytes=1024,
                source_revision=REVISION,
                source_matches_revision=True,
                build_command_id="flutter-appbundle-release",
                signed=True,
            ),
            ReleaseArtifactProvenanceV1(
                artifact_id="ios-release-archive",
                platform=ArtifactPlatform.IOS,
                media_type="application.ios-archive",
                sha256="c" * 64,
                size_bytes=2048,
                source_revision=REVISION,
                source_matches_revision=True,
                build_command_id="flutter-ios-release",
                signed=True,
            ),
        ),
        supply_chain=(
            SupplyChainComponentEvidenceV1(
                component_id="python-project-lock-input",
                sha256="d" * 64,
                size_bytes=100,
            ),
        ),
        gates=tuple(passing_gate(gate_id) for gate_id in REQUIRED_RELEASE_GATES),
    )


def test_auth_claims_are_bounded_and_content_safe() -> None:
    AuthClaims(subject="subject-a").validate_structure()

    with pytest.raises(AuthClaimValidationError) as captured:
        AuthClaims(subject=" private-subject ").validate_structure()

    assert captured.value.code == "auth_subject_invalid"
    assert "private-subject" not in str(captured.value)


def test_production_policy_requires_exact_issuer_audience_and_time_claims() -> None:
    policy = ProductionVerifierPolicy(
        issuer="https://identity.example.invalid",
        audience="convocoach-api",
        jwks_url="https://identity.example.invalid/keys.json",
    )
    claims = AuthClaims(
        subject="subject-a",
        issuer="https://identity.example.invalid",
        audiences=("convocoach-api",),
        issued_at=NOW - timedelta(minutes=5),
        expires_at=NOW + timedelta(minutes=5),
    )

    policy.validate_claims(claims, now=NOW)
    with pytest.raises(ProductionVerifierPolicyError) as captured:
        policy.validate_claims(
            replace(claims, audiences=("different-api",)),
            now=NOW,
        )

    assert captured.value.code == "auth_audience_mismatch"


@pytest.mark.parametrize(
    ("settings", "failure"),
    [
        (
            replace(production_settings(), authentication_verifier_mode="development"),
            "production_authentication_verifier_unsafe",
        ),
        (
            replace(
                production_settings(),
                authentication_jwks_url="http://identity.example.invalid/keys.json",
            ),
            "production_authentication_jwks_url_unsafe",
        ),
        (
            replace(production_settings(), authentication_allowed_algorithms=("HS256",)),
            "authentication_algorithms_unsafe",
        ),
        (
            replace(production_settings(), authentication_clock_skew_seconds=301),
            "authentication_clock_skew_invalid",
        ),
    ],
)
def test_production_authentication_configuration_fails_closed(
    settings: Settings,
    failure: str,
) -> None:
    with pytest.raises(SettingsValidationError) as captured:
        validate_settings(settings)

    assert failure in captured.value.failures


@pytest.mark.anyio
async def test_production_verifier_accepts_only_policy_validated_claims() -> None:
    settings = production_settings()
    validate_settings(settings)
    verifier = build_authentication_verifier(settings)

    assert isinstance(verifier, ProductionAuthenticationVerifier)
    assert verifier.policy.allowed_algorithms == ("ES256", "RS256")

    class Decoder:
        def decode(self, token: str) -> dict[str, object]:
            assert token == "private-production-token"
            return {
                "sub": "subject-a",
                "iss": settings.authentication_issuer,
                "aud": [settings.authentication_audience],
                "iat": int((datetime.now(UTC) - timedelta(minutes=5)).timestamp()),
                "exp": int((datetime.now(UTC) + timedelta(minutes=5)).timestamp()),
                "email": "verified@example.invalid",
                "email_verified": True,
                "permissions": ["read:user-metrics"],
                "scope": "openid profile",
            }

    verifier = ProductionAuthenticationVerifier(verifier.policy, decoder=Decoder())
    claims = await verifier.verify("private-production-token")
    assert claims.subject == "subject-a"
    assert claims.email == "verified@example.invalid"
    assert claims.permissions == ("read:user-metrics", "openid", "profile")


@pytest.mark.anyio
async def test_production_verifier_rejects_untrusted_claims_without_token_leakage() -> None:
    settings = production_settings()
    policy = ProductionVerifierPolicy(
        issuer=settings.authentication_issuer,
        audience=settings.authentication_audience,
        jwks_url=settings.authentication_jwks_url,
    )

    class Decoder:
        def decode(self, token: str) -> dict[str, object]:
            del token
            return {
                "sub": "subject-a",
                "iss": "https://attacker.example.invalid",
                "aud": settings.authentication_audience,
                "iat": int((datetime.now(UTC) - timedelta(minutes=5)).timestamp()),
                "exp": int((datetime.now(UTC) + timedelta(minutes=5)).timestamp()),
            }

    verifier = ProductionAuthenticationVerifier(policy, decoder=Decoder())
    with pytest.raises(AuthenticationError) as captured:
        await verifier.verify("private-production-token")
    assert captured.value.code == "authentication_failed"
    assert "private-production-token" not in str(captured.value)


def test_bearer_boundary_rejects_oversized_token(api_client: TestClient) -> None:
    response = api_client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {'x' * 8193}"},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid authentication credentials"}


@pytest.mark.anyio
async def test_current_user_stores_only_verified_email(tmp_path: Path) -> None:
    engine = create_database_engine(f"sqlite+aiosqlite:///{tmp_path / 'identity.db'}")
    session_factory = create_session_factory(engine)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    try:
        async with session_factory() as session:
            user = await UserRepository(session).get_or_create(
                AuthClaims(
                    subject="subject-a",
                    issuer=LOCAL_AUTH_ISSUER,
                    audiences=(LOCAL_AUTH_AUDIENCE,),
                    email="unverified@example.invalid",
                    email_verified=False,
                )
            )
            await session.commit()
            assert user.email is None
    finally:
        await engine.dispose()


def test_complete_release_candidate_qualifies_deterministically() -> None:
    report = ReleaseGateEvaluator().evaluate(complete_manifest())

    assert report.status.value == "qualified"
    assert report.blocking_gate_ids == ()
    assert report.failure_codes == ()


def test_checked_in_phase14_manifest_is_valid_and_truthfully_blocked() -> None:
    manifest_path = (
        Path(__file__).resolve().parents[2]
        / "release"
        / "phase14"
        / "release-candidate-manifest.example.json"
    )
    manifest = ReleaseCandidateManifestV1.model_validate_json(
        manifest_path.read_text(encoding="utf-8")
    )

    report = ReleaseGateEvaluator().evaluate(manifest)

    assert report.status.value == "blocked"
    assert ReleaseGateId.ANDROID_PHYSICAL_QUALIFICATION in report.blocking_gate_ids
    assert ReleaseGateId.IOS_PHYSICAL_QUALIFICATION in report.blocking_gate_ids
    assert ReleaseGateId.PRODUCTION_AUTHENTICATION in report.blocking_gate_ids


def test_realistic_phase14_candidate_remains_blocked() -> None:
    manifest = complete_manifest().model_copy(
        update={
            "source_worktree_clean": False,
            "source_matches_revision": False,
            "production_authentication_available": False,
            "phase6a3_status": GateStatus.BLOCKED,
            "artifacts": tuple(
                artifact.model_copy(
                    update={
                        "source_matches_revision": False,
                        "signed": False,
                    }
                )
                for artifact in complete_manifest().artifacts
            ),
            "gates": tuple(
                ReleaseGateEvidenceV1(
                    gate_id=gate.gate_id,
                    status=(
                        GateStatus.BLOCKED
                        if gate.gate_id
                        in {
                            ReleaseGateId.PRODUCTION_AUTHENTICATION,
                            ReleaseGateId.ANDROID_RELEASE_SIGNING,
                            ReleaseGateId.IOS_RELEASE_SIGNING,
                            ReleaseGateId.ANDROID_PHYSICAL_QUALIFICATION,
                            ReleaseGateId.IOS_PHYSICAL_QUALIFICATION,
                            ReleaseGateId.SOURCE_REVISION_CLEAN,
                            ReleaseGateId.CONTROLLED_LAUNCH_APPROVAL,
                        }
                        else GateStatus.PASS
                    ),
                    evidence_ids=gate.evidence_ids,
                    failure_codes=(
                        (f"{gate.gate_id.value}_blocked",)
                        if gate.gate_id
                        in {
                            ReleaseGateId.PRODUCTION_AUTHENTICATION,
                            ReleaseGateId.ANDROID_RELEASE_SIGNING,
                            ReleaseGateId.IOS_RELEASE_SIGNING,
                            ReleaseGateId.ANDROID_PHYSICAL_QUALIFICATION,
                            ReleaseGateId.IOS_PHYSICAL_QUALIFICATION,
                            ReleaseGateId.SOURCE_REVISION_CLEAN,
                            ReleaseGateId.CONTROLLED_LAUNCH_APPROVAL,
                        }
                        else ()
                    ),
                )
                for gate in complete_manifest().gates
            ),
        }
    )

    report = ReleaseGateEvaluator().evaluate(manifest)

    assert report.status.value == "blocked"
    assert "phase6a3_blocked" in report.failure_codes
    assert "production_authentication_unavailable" in report.failure_codes
    assert "android_artifact_unsigned" in report.failure_codes
    assert "ios_artifact_unsigned" in report.failure_codes


def test_evidence_collection_is_content_free_and_rejects_unsafe_paths(
    tmp_path: Path,
) -> None:
    private_sentinel = "private dependency content"
    lockfile = tmp_path / "dependency.lock"
    lockfile.write_text(private_sentinel, encoding="utf-8")

    evidence = collect_supply_chain_component(
        repository_root=tmp_path,
        relative_path="dependency.lock",
        component_id="dependency-lock",
    )
    serialized = evidence.model_dump_json()

    assert evidence.size_bytes == len(private_sentinel)
    assert private_sentinel not in serialized
    assert str(lockfile) not in serialized
    with pytest.raises(EvidenceCollectionError):
        collect_supply_chain_component(
            repository_root=tmp_path,
            relative_path="../outside.lock",
            component_id="outside-lock",
        )


def test_artifact_provenance_contains_digest_not_path_or_bytes(tmp_path: Path) -> None:
    private_sentinel = b"private-artifact-material"
    artifact_path = tmp_path / "app-release.aab"
    artifact_path.write_bytes(private_sentinel)

    provenance = collect_artifact_provenance(
        artifact_path=artifact_path,
        artifact_id="android-release-aab",
        platform=ArtifactPlatform.ANDROID,
        media_type="application.android-aab",
        source_revision=REVISION,
        source_matches_revision=False,
        build_command_id="flutter-appbundle-release",
        signed=False,
    )
    serialized = provenance.model_dump_json()

    assert provenance.size_bytes == len(private_sentinel)
    assert private_sentinel.decode() not in serialized
    assert str(artifact_path) not in serialized


def test_phase14_does_not_expand_the_ai_provider_registry() -> None:
    registry = build_default_provider_registry()

    assert tuple(metadata.identifier for metadata in registry) == ("mock-ai-provider.v1",)
