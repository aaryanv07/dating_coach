"""Deterministic release-gate aggregation."""

from app.release.contracts import (
    GateStatus,
    QualificationStatus,
    ReleaseCandidateManifestV1,
    ReleaseCandidateManifestV2,
    ReleaseGateId,
    ReleaseGateReportV1,
    ReleaseGateReportV2,
)

_V2_ONLY_GATES = frozenset(
    {
        ReleaseGateId.PRODUCTION_AI_QUALIFIED,
        ReleaseGateId.PRODUCTION_DEPLOYMENT,
        ReleaseGateId.STORE_BILLING_QUALIFIED,
        ReleaseGateId.BACKUP_RESTORE_QUALIFIED,
        ReleaseGateId.OBSERVABILITY_ALERTING_QUALIFIED,
        ReleaseGateId.LEGAL_PRIVACY_REVIEW,
    }
)
REQUIRED_RELEASE_GATES = frozenset(gate for gate in ReleaseGateId if gate not in _V2_ONLY_GATES)
REQUIRED_RELEASE_GATES_V2 = frozenset(
    gate for gate in ReleaseGateId if gate != ReleaseGateId.PRODUCTION_AI_DISABLED
)


class ReleaseGateEvaluator:
    """Fail closed unless every mandatory release condition is evidenced."""

    def evaluate(
        self,
        manifest: ReleaseCandidateManifestV1 | ReleaseCandidateManifestV2,
    ) -> ReleaseGateReportV1 | ReleaseGateReportV2:
        if isinstance(manifest, ReleaseCandidateManifestV2):
            return self._evaluate_v2(manifest)
        return self._evaluate_v1(manifest)

    def _evaluate_v1(self, manifest: ReleaseCandidateManifestV1) -> ReleaseGateReportV1:
        statuses = {gate.gate_id: gate for gate in manifest.gates}
        blocking_gates: set[ReleaseGateId] = set()
        failures: set[str] = set()

        for gate_id in REQUIRED_RELEASE_GATES:
            evidence = statuses.get(gate_id)
            if evidence is None:
                blocking_gates.add(gate_id)
                failures.add(f"missing_{gate_id.value}")
                continue
            if evidence.status != GateStatus.PASS:
                blocking_gates.add(gate_id)
                failures.update(evidence.failure_codes)

        if manifest.phase6a3_status != GateStatus.PASS:
            blocking_gates.update(
                {
                    ReleaseGateId.ANDROID_PHYSICAL_QUALIFICATION,
                    ReleaseGateId.IOS_PHYSICAL_QUALIFICATION,
                }
            )
            failures.add("phase6a3_blocked")
        if not manifest.source_worktree_clean:
            blocking_gates.add(ReleaseGateId.SOURCE_REVISION_CLEAN)
            failures.add("source_worktree_dirty")
        if not manifest.source_matches_revision:
            blocking_gates.add(ReleaseGateId.SOURCE_REVISION_CLEAN)
            failures.add("source_revision_mismatch")
        if not manifest.production_authentication_available:
            blocking_gates.add(ReleaseGateId.PRODUCTION_AUTHENTICATION)
            failures.add("production_authentication_unavailable")
        if manifest.ai_execution_enabled:
            blocking_gates.add(ReleaseGateId.PRODUCTION_AI_DISABLED)
            failures.add("production_ai_enabled")
        if manifest.mock_execution_enabled:
            blocking_gates.add(ReleaseGateId.MOCK_EXECUTION_DISABLED)
            failures.add("mock_execution_enabled")
        if not manifest.artifacts:
            blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
            failures.add("release_artifact_missing")
        for artifact in manifest.artifacts:
            if artifact.source_revision != manifest.source_revision:
                blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
                failures.add("artifact_source_revision_mismatch")
            if not artifact.source_matches_revision:
                blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
                failures.add("artifact_provenance_unverified")
            if not artifact.signed:
                signing_gate_id = (
                    ReleaseGateId.ANDROID_RELEASE_SIGNING
                    if artifact.platform.value == "android"
                    else ReleaseGateId.IOS_RELEASE_SIGNING
                )
                blocking_gates.add(signing_gate_id)
                failures.add(f"{artifact.platform.value}_artifact_unsigned")
        if not manifest.supply_chain:
            blocking_gates.add(ReleaseGateId.SUPPLY_CHAIN_EVIDENCE)
            failures.add("supply_chain_evidence_missing")

        return ReleaseGateReportV1(
            candidate_id=manifest.candidate_id,
            status=(
                QualificationStatus.BLOCKED
                if blocking_gates or failures
                else QualificationStatus.QUALIFIED
            ),
            blocking_gate_ids=tuple(sorted(blocking_gates, key=lambda gate: gate.value)),
            failure_codes=tuple(sorted(failures)),
        )

    def _evaluate_v2(self, manifest: ReleaseCandidateManifestV2) -> ReleaseGateReportV2:
        statuses = {gate.gate_id: gate for gate in manifest.gates}
        blocking_gates: set[ReleaseGateId] = set()
        failures: set[str] = set()

        for gate_id in REQUIRED_RELEASE_GATES_V2:
            evidence = statuses.get(gate_id)
            if evidence is None:
                blocking_gates.add(gate_id)
                failures.add(f"missing_{gate_id.value}")
            elif evidence.status != GateStatus.PASS:
                blocking_gates.add(gate_id)
                failures.update(evidence.failure_codes)

        self._evaluate_common(manifest, blocking_gates, failures)
        structured_gates = (
            (
                manifest.production_deployment_available,
                ReleaseGateId.PRODUCTION_DEPLOYMENT,
                "production_deployment_unavailable",
            ),
            (
                manifest.store_billing_available,
                ReleaseGateId.STORE_BILLING_QUALIFIED,
                "store_billing_unavailable",
            ),
            (
                manifest.backup_restore_verified,
                ReleaseGateId.BACKUP_RESTORE_QUALIFIED,
                "backup_restore_unverified",
            ),
            (
                manifest.observability_alerting_available,
                ReleaseGateId.OBSERVABILITY_ALERTING_QUALIFIED,
                "observability_alerting_unavailable",
            ),
            (
                manifest.legal_privacy_review_approved,
                ReleaseGateId.LEGAL_PRIVACY_REVIEW,
                "legal_privacy_review_unapproved",
            ),
        )
        for available, structured_gate_id, failure in structured_gates:
            if not available:
                blocking_gates.add(structured_gate_id)
                failures.add(failure)
        if manifest.ai_execution_enabled and not all(
            (
                manifest.ai_provider_qualified,
                manifest.ai_usage_enforcement_enabled,
                manifest.external_ai_processing_approved,
                manifest.live_ai_safety_evaluation_passed,
            )
        ):
            blocking_gates.add(ReleaseGateId.PRODUCTION_AI_QUALIFIED)
            if not manifest.ai_provider_qualified:
                failures.add("production_ai_provider_unqualified")
            if not manifest.ai_usage_enforcement_enabled:
                failures.add("production_ai_usage_enforcement_disabled")
            if not manifest.external_ai_processing_approved:
                failures.add("production_ai_processing_unapproved")
            if not manifest.live_ai_safety_evaluation_passed:
                failures.add("production_ai_safety_evaluation_missing")

        return ReleaseGateReportV2(
            candidate_id=manifest.candidate_id,
            status=(
                QualificationStatus.BLOCKED
                if blocking_gates or failures
                else QualificationStatus.QUALIFIED
            ),
            blocking_gate_ids=tuple(sorted(blocking_gates, key=lambda gate: gate.value)),
            failure_codes=tuple(sorted(failures)),
        )

    @staticmethod
    def _evaluate_common(
        manifest: ReleaseCandidateManifestV2,
        blocking_gates: set[ReleaseGateId],
        failures: set[str],
    ) -> None:
        if manifest.phase6a3_status != GateStatus.PASS:
            blocking_gates.update(
                {
                    ReleaseGateId.ANDROID_PHYSICAL_QUALIFICATION,
                    ReleaseGateId.IOS_PHYSICAL_QUALIFICATION,
                }
            )
            failures.add("phase6a3_blocked")
        if not manifest.source_worktree_clean or not manifest.source_matches_revision:
            blocking_gates.add(ReleaseGateId.SOURCE_REVISION_CLEAN)
            if not manifest.source_worktree_clean:
                failures.add("source_worktree_dirty")
            if not manifest.source_matches_revision:
                failures.add("source_revision_mismatch")
        if not manifest.production_authentication_available:
            blocking_gates.add(ReleaseGateId.PRODUCTION_AUTHENTICATION)
            failures.add("production_authentication_unavailable")
        if manifest.mock_execution_enabled:
            blocking_gates.add(ReleaseGateId.MOCK_EXECUTION_DISABLED)
            failures.add("mock_execution_enabled")
        if not manifest.artifacts:
            blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
            failures.add("release_artifact_missing")
        for artifact in manifest.artifacts:
            if artifact.source_revision != manifest.source_revision:
                blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
                failures.add("artifact_source_revision_mismatch")
            if not artifact.source_matches_revision:
                blocking_gates.add(ReleaseGateId.ARTIFACT_PROVENANCE)
                failures.add("artifact_provenance_unverified")
            if not artifact.signed:
                gate_id = (
                    ReleaseGateId.ANDROID_RELEASE_SIGNING
                    if artifact.platform.value == "android"
                    else ReleaseGateId.IOS_RELEASE_SIGNING
                )
                blocking_gates.add(gate_id)
                failures.add(f"{artifact.platform.value}_artifact_unsigned")
        if not manifest.supply_chain:
            blocking_gates.add(ReleaseGateId.SUPPLY_CHAIN_EVIDENCE)
            failures.add("supply_chain_evidence_missing")
