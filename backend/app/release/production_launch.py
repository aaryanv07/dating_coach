"""Granular, content-free production launch qualification contract."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, field_validator

from app.release.contracts import Identifier, QualificationStatus, SourceRevision


class ProductionLaunchEvidenceV1(BaseModel):
    """Facts that must be independently evidenced before public availability."""

    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)

    schema_version: Literal["production-launch-evidence.v1"] = "production-launch-evidence.v1"
    candidate_id: Identifier
    source_revision: SourceRevision
    generated_at: datetime

    oidc_tenant_configured: bool
    google_oidc_registered: bool
    apple_oidc_registered: bool
    oidc_redirects_verified: bool
    oidc_sign_in_sign_out_sandbox_passed: bool

    apple_products_active: bool
    google_products_active: bool
    apple_server_notifications_v2_passed: bool
    google_rtdn_authenticated_push_passed: bool
    apple_sandbox_purchase_restore_refund_passed: bool
    google_sandbox_purchase_restore_refund_passed: bool
    server_receipt_verification_passed: bool

    production_api_https_ready: bool
    postgres_ready: bool
    redis_tls_ready: bool
    migration_rollback_passed: bool
    backup_restore_drill_passed: bool
    alert_delivery_drill_passed: bool

    ios_distribution_signed: bool
    android_distribution_signed: bool
    ios_physical_qualification_passed: bool
    android_physical_qualification_passed: bool

    privacy_policy_published: bool
    terms_published: bool
    account_export_deletion_verified: bool
    ai_processor_review_approved: bool
    legal_privacy_review_approved: bool
    independent_ai_safety_approved: bool
    store_review_metadata_approved: bool
    controlled_launch_owner_approved: bool

    evidence_ids: tuple[Identifier, ...]

    @field_validator("generated_at")
    @classmethod
    def require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("generated_at_timezone_required")
        return value

    @field_validator("evidence_ids")
    @classmethod
    def require_unique_evidence(cls, values: tuple[str, ...]) -> tuple[str, ...]:
        if not values or len(values) != len(set(values)):
            raise ValueError("launch_evidence_missing_or_duplicate")
        return values


class ProductionLaunchReportV1(BaseModel):
    """Safe aggregate that never contains credentials or user content."""

    model_config = ConfigDict(extra="forbid", frozen=True, strict=True)

    schema_version: Literal["production-launch-report.v1"] = "production-launch-report.v1"
    candidate_id: Identifier
    status: QualificationStatus
    failure_codes: tuple[Identifier, ...]


_METADATA_FIELDS = frozenset(
    {"schema_version", "candidate_id", "source_revision", "generated_at", "evidence_ids"}
)


def evaluate_production_launch(
    evidence: ProductionLaunchEvidenceV1,
) -> ProductionLaunchReportV1:
    """Block launch for every absent required fact, including manual approvals."""
    payload = evidence.model_dump()
    failures = tuple(
        sorted(
            f"{field_name}_missing"
            for field_name, value in payload.items()
            if field_name not in _METADATA_FIELDS and value is not True
        )
    )
    return ProductionLaunchReportV1(
        candidate_id=evidence.candidate_id,
        status=(QualificationStatus.BLOCKED if failures else QualificationStatus.QUALIFIED),
        failure_codes=failures,
    )
