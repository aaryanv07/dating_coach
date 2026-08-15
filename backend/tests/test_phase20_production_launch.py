"""Granular production launch gate tests."""

from datetime import UTC, datetime

import pytest

from app.release.contracts import QualificationStatus
from app.release.production_launch import (
    ProductionLaunchEvidenceV1,
    evaluate_production_launch,
)


def _evidence() -> ProductionLaunchEvidenceV1:
    return ProductionLaunchEvidenceV1(
        candidate_id="production-launch",
        source_revision="a" * 40,
        generated_at=datetime(2026, 8, 3, tzinfo=UTC),
        oidc_tenant_configured=True,
        google_oidc_registered=True,
        apple_oidc_registered=True,
        oidc_redirects_verified=True,
        oidc_sign_in_sign_out_sandbox_passed=True,
        apple_products_active=True,
        google_products_active=True,
        apple_server_notifications_v2_passed=True,
        google_rtdn_authenticated_push_passed=True,
        apple_sandbox_purchase_restore_refund_passed=True,
        google_sandbox_purchase_restore_refund_passed=True,
        server_receipt_verification_passed=True,
        production_api_https_ready=True,
        postgres_ready=True,
        redis_tls_ready=True,
        migration_rollback_passed=True,
        backup_restore_drill_passed=True,
        alert_delivery_drill_passed=True,
        ios_distribution_signed=True,
        android_distribution_signed=True,
        ios_physical_qualification_passed=True,
        android_physical_qualification_passed=True,
        privacy_policy_published=True,
        terms_published=True,
        account_export_deletion_verified=True,
        ai_processor_review_approved=True,
        legal_privacy_review_approved=True,
        independent_ai_safety_approved=True,
        store_review_metadata_approved=True,
        controlled_launch_owner_approved=True,
        evidence_ids=("launch.review",),
    )


def test_launch_qualifies_only_when_every_fact_is_true() -> None:
    report = evaluate_production_launch(_evidence())

    assert report.status == QualificationStatus.QUALIFIED
    assert report.failure_codes == ()


@pytest.mark.parametrize(
    "field_name",
    [
        "google_oidc_registered",
        "apple_server_notifications_v2_passed",
        "google_sandbox_purchase_restore_refund_passed",
        "backup_restore_drill_passed",
        "alert_delivery_drill_passed",
        "android_distribution_signed",
        "ios_physical_qualification_passed",
        "legal_privacy_review_approved",
        "independent_ai_safety_approved",
        "controlled_launch_owner_approved",
    ],
)
def test_launch_blocks_each_missing_external_fact(field_name: str) -> None:
    evidence = _evidence().model_copy(update={field_name: False})

    report = evaluate_production_launch(evidence)

    assert report.status == QualificationStatus.BLOCKED
    assert f"{field_name}_missing" in report.failure_codes
