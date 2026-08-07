"""Strict, content-free release qualification contracts."""

from datetime import datetime
from enum import StrEnum
from typing import Annotated, Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

Identifier = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=96,
        pattern=r"^[a-z0-9][a-z0-9._-]*$",
    ),
]
Sha256Digest = Annotated[str, StringConstraints(pattern=r"^[a-f0-9]{64}$")]
SourceRevision = Annotated[str, StringConstraints(pattern=r"^[a-f0-9]{40}$")]


class ReleaseGateId(StrEnum):
    """Closed release gate catalog."""

    BACKEND_QUALITY = "backend_quality"
    FLUTTER_QUALITY = "flutter_quality"
    DATABASE_MIGRATIONS = "database_migrations"
    REPOSITORY_VALIDATION = "repository_validation"
    PRIVACY_SECURITY_SCANS = "privacy_security_scans"
    SUPPLY_CHAIN_EVIDENCE = "supply_chain_evidence"
    ARTIFACT_PROVENANCE = "artifact_provenance"
    ANDROID_RELEASE_BUILD = "android_release_build"
    IOS_RELEASE_BUILD = "ios_release_build"
    ANDROID_RELEASE_SIGNING = "android_release_signing"
    IOS_RELEASE_SIGNING = "ios_release_signing"
    ANDROID_PHYSICAL_QUALIFICATION = "android_physical_qualification"
    IOS_PHYSICAL_QUALIFICATION = "ios_physical_qualification"
    PRODUCTION_AUTHENTICATION = "production_authentication"
    PRODUCTION_AI_DISABLED = "production_ai_disabled"
    PRODUCTION_AI_QUALIFIED = "production_ai_qualified"
    PRODUCTION_DEPLOYMENT = "production_deployment"
    STORE_BILLING_QUALIFIED = "store_billing_qualified"
    BACKUP_RESTORE_QUALIFIED = "backup_restore_qualified"
    OBSERVABILITY_ALERTING_QUALIFIED = "observability_alerting_qualified"
    LEGAL_PRIVACY_REVIEW = "legal_privacy_review"
    MOCK_EXECUTION_DISABLED = "mock_execution_disabled"
    SOURCE_REVISION_CLEAN = "source_revision_clean"
    CONTROLLED_LAUNCH_APPROVAL = "controlled_launch_approval"


class GateStatus(StrEnum):
    """Machine-evaluable gate status."""

    PASS = "pass"
    FAIL = "fail"
    BLOCKED = "blocked"
    NOT_RUN = "not_run"


class QualificationStatus(StrEnum):
    """Aggregated release-candidate status."""

    QUALIFIED = "qualified"
    BLOCKED = "blocked"


class ArtifactPlatform(StrEnum):
    """Closed mobile artifact platform."""

    ANDROID = "android"
    IOS = "ios"


class StrictContract(BaseModel):
    """Forbid undocumented fields and mutation."""

    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)


class ReleaseArtifactProvenanceV1(StrictContract):
    """Content-free provenance for one mobile build artifact."""

    schema_version: Literal["release-artifact-provenance.v1"] = "release-artifact-provenance.v1"
    artifact_id: Identifier
    platform: ArtifactPlatform
    media_type: Identifier
    sha256: Sha256Digest
    size_bytes: int = Field(gt=0)
    source_revision: SourceRevision
    source_matches_revision: bool
    build_command_id: Identifier
    signed: bool


class SupplyChainComponentEvidenceV1(StrictContract):
    """Digest evidence for one allowlisted dependency or toolchain input."""

    schema_version: Literal["supply-chain-component-evidence.v1"] = (
        "supply-chain-component-evidence.v1"
    )
    component_id: Identifier
    sha256: Sha256Digest
    size_bytes: int = Field(gt=0)


class ReleaseGateEvidenceV1(StrictContract):
    """One content-free automated or manual gate result."""

    schema_version: Literal["release-gate-evidence.v1"] = "release-gate-evidence.v1"
    gate_id: ReleaseGateId
    status: GateStatus
    evidence_ids: tuple[Identifier, ...] = ()
    failure_codes: tuple[Identifier, ...] = ()

    @model_validator(mode="after")
    def validate_status_details(self) -> "ReleaseGateEvidenceV1":
        if self.status == GateStatus.PASS and self.failure_codes:
            raise ValueError("passing_gate_has_failure_codes")
        if self.status != GateStatus.PASS and not self.failure_codes:
            raise ValueError("nonpassing_gate_missing_failure_code")
        if len(set(self.evidence_ids)) != len(self.evidence_ids):
            raise ValueError("duplicate_evidence_id")
        if len(set(self.failure_codes)) != len(self.failure_codes):
            raise ValueError("duplicate_failure_code")
        return self


class ReleaseGateEvidenceV2(StrictContract):
    """One content-free gate result for the production-AI-aware catalog."""

    schema_version: Literal["release-gate-evidence.v2"] = "release-gate-evidence.v2"
    gate_id: ReleaseGateId
    status: GateStatus
    evidence_ids: tuple[Identifier, ...] = ()
    failure_codes: tuple[Identifier, ...] = ()

    @model_validator(mode="after")
    def validate_status_details(self) -> "ReleaseGateEvidenceV2":
        if self.status == GateStatus.PASS and self.failure_codes:
            raise ValueError("passing_gate_has_failure_codes")
        if self.status != GateStatus.PASS and not self.failure_codes:
            raise ValueError("nonpassing_gate_missing_failure_code")
        if len(set(self.evidence_ids)) != len(self.evidence_ids):
            raise ValueError("duplicate_evidence_id")
        if len(set(self.failure_codes)) != len(self.failure_codes):
            raise ValueError("duplicate_failure_code")
        return self


class ReleaseCandidateManifestV1(StrictContract):
    """Complete input to deterministic release-gate aggregation."""

    schema_version: Literal["release-candidate-manifest.v1"] = "release-candidate-manifest.v1"
    candidate_id: Identifier
    application_version: Identifier
    generated_at: datetime
    source_revision: SourceRevision
    source_worktree_clean: bool
    source_matches_revision: bool
    environment: Literal["production"]
    authentication_verifier_mode: Literal["production_contract"]
    production_authentication_available: bool
    ai_execution_enabled: bool
    mock_execution_enabled: bool
    phase6a3_status: GateStatus
    artifacts: tuple[ReleaseArtifactProvenanceV1, ...]
    supply_chain: tuple[SupplyChainComponentEvidenceV1, ...]
    gates: tuple[ReleaseGateEvidenceV1, ...]

    @field_validator("generated_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("generated_at_timezone_required")
        return value

    @model_validator(mode="after")
    def validate_uniqueness_and_scope(self) -> "ReleaseCandidateManifestV1":
        artifact_ids = [artifact.artifact_id for artifact in self.artifacts]
        component_ids = [component.component_id for component in self.supply_chain]
        gate_ids = [gate.gate_id for gate in self.gates]
        if len(set(artifact_ids)) != len(artifact_ids):
            raise ValueError("duplicate_artifact_id")
        if len(set(component_ids)) != len(component_ids):
            raise ValueError("duplicate_supply_chain_component")
        if len(set(gate_ids)) != len(gate_ids):
            raise ValueError("duplicate_release_gate")
        if self.phase6a3_status not in {GateStatus.PASS, GateStatus.BLOCKED}:
            raise ValueError("phase6a3_status_invalid")
        return self


class ReleaseCandidateManifestV2(StrictContract):
    """Production candidate contract that can qualify one reviewed AI provider."""

    schema_version: Literal["release-candidate-manifest.v2"] = "release-candidate-manifest.v2"
    candidate_id: Identifier
    application_version: Identifier
    generated_at: datetime
    source_revision: SourceRevision
    source_worktree_clean: bool
    source_matches_revision: bool
    environment: Literal["production"]
    authentication_verifier_mode: Literal["production_contract"]
    production_authentication_available: bool
    ai_execution_enabled: bool
    ai_provider_mode: Literal["disabled", "zai_glm", "openrouter_tiered"]
    ai_provider_qualified: bool
    ai_usage_enforcement_enabled: bool
    external_ai_processing_approved: bool
    live_ai_safety_evaluation_passed: bool
    production_deployment_available: bool
    store_billing_available: bool
    backup_restore_verified: bool
    observability_alerting_available: bool
    legal_privacy_review_approved: bool
    mock_execution_enabled: bool
    phase6a3_status: GateStatus
    artifacts: tuple[ReleaseArtifactProvenanceV1, ...]
    supply_chain: tuple[SupplyChainComponentEvidenceV1, ...]
    gates: tuple[ReleaseGateEvidenceV2, ...]

    @field_validator("generated_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("generated_at_timezone_required")
        return value

    @model_validator(mode="after")
    def validate_uniqueness_and_scope(self) -> "ReleaseCandidateManifestV2":
        artifact_ids = [artifact.artifact_id for artifact in self.artifacts]
        component_ids = [component.component_id for component in self.supply_chain]
        gate_ids = [gate.gate_id for gate in self.gates]
        if len(set(artifact_ids)) != len(artifact_ids):
            raise ValueError("duplicate_artifact_id")
        if len(set(component_ids)) != len(component_ids):
            raise ValueError("duplicate_supply_chain_component")
        if len(set(gate_ids)) != len(gate_ids):
            raise ValueError("duplicate_release_gate")
        if self.phase6a3_status not in {GateStatus.PASS, GateStatus.BLOCKED}:
            raise ValueError("phase6a3_status_invalid")
        if self.ai_execution_enabled and self.ai_provider_mode not in {
            "zai_glm",
            "openrouter_tiered",
        }:
            raise ValueError("enabled_ai_provider_invalid")
        if not self.ai_execution_enabled and self.ai_provider_mode != "disabled":
            raise ValueError("disabled_ai_provider_invalid")
        return self


class ReleaseGateReportV1(StrictContract):
    """Content-free deterministic qualification result."""

    schema_version: Literal["release-gate-report.v1"] = "release-gate-report.v1"
    candidate_id: Identifier
    status: QualificationStatus
    blocking_gate_ids: tuple[ReleaseGateId, ...]
    failure_codes: tuple[Identifier, ...]


class ReleaseGateReportV2(StrictContract):
    """Content-free qualification result for a v2 candidate."""

    schema_version: Literal["release-gate-report.v2"] = "release-gate-report.v2"
    candidate_id: Identifier
    status: QualificationStatus
    blocking_gate_ids: tuple[ReleaseGateId, ...]
    failure_codes: tuple[Identifier, ...]
