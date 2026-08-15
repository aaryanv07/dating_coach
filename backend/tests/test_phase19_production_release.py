"""Production-AI-aware release qualification tests."""

from datetime import UTC, datetime
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.release.cli import main as release_cli_main
from app.release.contracts import (
    ArtifactPlatform,
    GateStatus,
    QualificationStatus,
    ReleaseArtifactProvenanceV1,
    ReleaseCandidateManifestV2,
    ReleaseGateEvidenceV2,
    ReleaseGateId,
    SupplyChainComponentEvidenceV1,
)
from app.release.gates import REQUIRED_RELEASE_GATES_V2, ReleaseGateEvaluator

REVISION = "a" * 40


def _passing_gate(gate_id: ReleaseGateId) -> ReleaseGateEvidenceV2:
    return ReleaseGateEvidenceV2(
        gate_id=gate_id,
        status=GateStatus.PASS,
        evidence_ids=(f"{gate_id.value}.evidence",),
    )


def _manifest() -> ReleaseCandidateManifestV2:
    return ReleaseCandidateManifestV2(
        candidate_id="phase19-production-ai",
        application_version="0.2.0-5",
        generated_at=datetime(2026, 7, 29, 16, 0, tzinfo=UTC),
        source_revision=REVISION,
        source_worktree_clean=True,
        source_matches_revision=True,
        environment="production",
        authentication_verifier_mode="production_contract",
        production_authentication_available=True,
        ai_execution_enabled=True,
        ai_provider_mode="zai_glm",
        ai_provider_qualified=True,
        ai_usage_enforcement_enabled=True,
        external_ai_processing_approved=True,
        live_ai_safety_evaluation_passed=True,
        production_deployment_available=True,
        store_billing_available=True,
        backup_restore_verified=True,
        observability_alerting_available=True,
        legal_privacy_review_approved=True,
        mock_execution_enabled=False,
        phase6a3_status=GateStatus.PASS,
        artifacts=(
            ReleaseArtifactProvenanceV1(
                artifact_id="ios-release-archive",
                platform=ArtifactPlatform.IOS,
                media_type="application.ios-archive",
                sha256="b" * 64,
                size_bytes=2048,
                source_revision=REVISION,
                source_matches_revision=True,
                build_command_id="flutter-ios-release",
                signed=True,
            ),
        ),
        supply_chain=(
            SupplyChainComponentEvidenceV1(
                component_id="backend-runtime-lock",
                sha256="c" * 64,
                size_bytes=128,
            ),
        ),
        gates=tuple(_passing_gate(gate) for gate in REQUIRED_RELEASE_GATES_V2),
    )


def test_v2_candidate_can_qualify_reviewed_production_glm() -> None:
    report = ReleaseGateEvaluator().evaluate(_manifest())

    assert report.status == QualificationStatus.QUALIFIED
    assert report.blocking_gate_ids == ()
    assert report.failure_codes == ()
    assert report.schema_version == "release-gate-report.v2"


def test_v2_cli_uses_json_contract_semantics(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    manifest_path = tmp_path / "candidate.json"
    manifest_path.write_text(_manifest().model_dump_json(), encoding="utf-8")

    exit_code = release_cli_main([str(manifest_path), "--expect-status", "qualified"])

    assert exit_code == 0
    assert '"schema_version":"release-gate-report.v2"' in capsys.readouterr().out


@pytest.mark.parametrize(
    ("field", "failure"),
    [
        ("ai_provider_qualified", "production_ai_provider_unqualified"),
        (
            "ai_usage_enforcement_enabled",
            "production_ai_usage_enforcement_disabled",
        ),
        (
            "external_ai_processing_approved",
            "production_ai_processing_unapproved",
        ),
        (
            "live_ai_safety_evaluation_passed",
            "production_ai_safety_evaluation_missing",
        ),
    ],
)
def test_v2_candidate_fails_closed_when_ai_evidence_is_missing(
    field: str,
    failure: str,
) -> None:
    report = ReleaseGateEvaluator().evaluate(_manifest().model_copy(update={field: False}))

    assert report.status == QualificationStatus.BLOCKED
    assert ReleaseGateId.PRODUCTION_AI_QUALIFIED in report.blocking_gate_ids
    assert failure in report.failure_codes


def test_v2_candidate_rejects_provider_state_mismatch() -> None:
    payload = _manifest().model_dump(mode="json")
    payload["ai_provider_mode"] = "disabled"

    with pytest.raises(ValidationError):
        ReleaseCandidateManifestV2.model_validate(payload)


@pytest.mark.parametrize(
    ("field", "gate", "failure"),
    [
        (
            "production_deployment_available",
            ReleaseGateId.PRODUCTION_DEPLOYMENT,
            "production_deployment_unavailable",
        ),
        (
            "store_billing_available",
            ReleaseGateId.STORE_BILLING_QUALIFIED,
            "store_billing_unavailable",
        ),
        (
            "backup_restore_verified",
            ReleaseGateId.BACKUP_RESTORE_QUALIFIED,
            "backup_restore_unverified",
        ),
        (
            "observability_alerting_available",
            ReleaseGateId.OBSERVABILITY_ALERTING_QUALIFIED,
            "observability_alerting_unavailable",
        ),
        (
            "legal_privacy_review_approved",
            ReleaseGateId.LEGAL_PRIVACY_REVIEW,
            "legal_privacy_review_unapproved",
        ),
    ],
)
def test_v2_candidate_cannot_hide_external_launch_prerequisites(
    field: str,
    gate: ReleaseGateId,
    failure: str,
) -> None:
    report = ReleaseGateEvaluator().evaluate(_manifest().model_copy(update={field: False}))

    assert report.status == QualificationStatus.BLOCKED
    assert gate in report.blocking_gate_ids
    assert failure in report.failure_codes
