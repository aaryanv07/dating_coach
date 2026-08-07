"""Phase 15 freemium catalog and allowance-policy foundation tests."""

from dataclasses import FrozenInstanceError, replace

import pytest
from fastapi.testclient import TestClient

from app.subscriptions.catalog import (
    FREE_PLAN,
    PLUS_PLAN,
    SUBSCRIPTION_CATALOG,
    SUBSCRIPTION_CATALOG_VERSION,
    WELCOME_PLAN,
    plan_for,
)
from app.subscriptions.contracts import (
    AllowanceConsumptionV1,
    AllowanceDecisionV1,
    AllowanceKind,
    AllowanceResetPeriod,
    BillingPeriod,
    NonPaywalledCapability,
    PlanAllowanceV1,
    StorePriceV1,
    SubscriptionPlanCode,
)
from app.subscriptions.policy import evaluate_allowance


def test_catalog_contains_the_approved_closed_plan_set() -> None:
    assert SUBSCRIPTION_CATALOG_VERSION == "subscription-catalog.v1"
    assert tuple(plan.code for plan in SUBSCRIPTION_CATALOG) == (
        SubscriptionPlanCode.WELCOME,
        SubscriptionPlanCode.FREE,
        SubscriptionPlanCode.PLUS,
    )
    assert plan_for(SubscriptionPlanCode.FREE) is FREE_PLAN
    assert [plan.purchase_enabled for plan in SUBSCRIPTION_CATALOG] == [False, False, True]


def test_approved_prices_use_exact_integer_minor_units() -> None:
    prices = {price.billing_period: price for price in PLUS_PLAN.prices}

    assert prices[BillingPeriod.MONTHLY].amount_minor == 99_900
    assert prices[BillingPeriod.YEARLY].amount_minor == 899_900
    assert {price.currency for price in PLUS_PLAN.prices} == {"INR"}
    assert WELCOME_PLAN.prices == ()
    assert FREE_PLAN.prices == ()


@pytest.mark.parametrize(
    ("plan_code", "expected_limits"),
    [
        (
            SubscriptionPlanCode.WELCOME,
            {
                AllowanceKind.CONVERSATION_ANALYSIS: 5,
                AllowanceKind.REPLY_GENERATION: 25,
                AllowanceKind.FIRST_MESSAGE_GENERATION: 5,
                AllowanceKind.PROGRESS_INSIGHT: 4,
            },
        ),
        (
            SubscriptionPlanCode.FREE,
            {
                AllowanceKind.CONVERSATION_ANALYSIS: 2,
                AllowanceKind.REPLY_GENERATION: 10,
                AllowanceKind.FIRST_MESSAGE_GENERATION: 3,
                AllowanceKind.PROGRESS_INSIGHT: 1,
            },
        ),
        (
            SubscriptionPlanCode.PLUS,
            {
                AllowanceKind.CONVERSATION_ANALYSIS: 12,
                AllowanceKind.REPLY_GENERATION: 80,
                AllowanceKind.FIRST_MESSAGE_GENERATION: 10,
                AllowanceKind.PROGRESS_INSIGHT: 4,
            },
        ),
    ],
)
def test_plan_allowances_match_the_approved_limits(
    plan_code: SubscriptionPlanCode,
    expected_limits: dict[AllowanceKind, int],
) -> None:
    plan = plan_for(plan_code)

    assert {item.kind: item.limit for item in plan.allowances} == expected_limits


def test_allowance_policy_is_deterministic_and_fails_closed_at_the_limit() -> None:
    available = evaluate_allowance(
        PLUS_PLAN,
        AllowanceConsumptionV1(
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            consumed=11,
        ),
    )
    exhausted = evaluate_allowance(
        PLUS_PLAN,
        AllowanceConsumptionV1(
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            consumed=12,
        ),
    )
    over_limit = evaluate_allowance(
        PLUS_PLAN,
        AllowanceConsumptionV1(
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            consumed=99,
        ),
    )

    assert (available.remaining, available.request_allowed) == (1, True)
    assert (exhausted.remaining, exhausted.request_allowed) == (0, False)
    assert (over_limit.remaining, over_limit.request_allowed) == (0, False)


def test_progress_reset_periods_are_explicit() -> None:
    def progress_reset(plan_code: SubscriptionPlanCode) -> AllowanceResetPeriod:
        return next(
            item.reset_period
            for item in plan_for(plan_code).allowances
            if item.kind == AllowanceKind.PROGRESS_INSIGHT
        )

    assert progress_reset(SubscriptionPlanCode.WELCOME) == AllowanceResetPeriod.WEEKLY
    assert progress_reset(SubscriptionPlanCode.FREE) == AllowanceResetPeriod.MONTHLY
    assert progress_reset(SubscriptionPlanCode.PLUS) == AllowanceResetPeriod.WEEKLY


def test_every_plan_preserves_non_paywalled_protections() -> None:
    for plan in SUBSCRIPTION_CATALOG:
        assert set(plan.non_paywalled_capabilities) == set(NonPaywalledCapability)


def test_contracts_reject_invalid_purchase_configuration() -> None:
    with pytest.raises(ValueError):
        StorePriceV1(amount_minor=0, billing_period=BillingPeriod.MONTHLY)
    with pytest.raises(ValueError):
        PlanAllowanceV1(
            kind=AllowanceKind.REPLY_GENERATION,
            limit=0,
            reset_period=AllowanceResetPeriod.MONTHLY,
        )
    with pytest.raises(ValueError):
        replace(FREE_PLAN, purchase_enabled=True)
    with pytest.raises(ValueError):
        AllowanceConsumptionV1(
            kind=AllowanceKind.REPLY_GENERATION,
            consumed=-1,
        )
    with pytest.raises(ValueError):
        AllowanceDecisionV1(
            kind=AllowanceKind.REPLY_GENERATION,
            limit=10,
            consumed=10,
            remaining=1,
            request_allowed=True,
            reset_period=AllowanceResetPeriod.MONTHLY,
        )


def test_catalog_contracts_are_immutable_and_content_free() -> None:
    with pytest.raises(FrozenInstanceError):
        PLUS_PLAN.display_name = "changed"  # type: ignore[misc]

    field_names = set(AllowanceConsumptionV1.__dataclass_fields__)
    assert field_names == {"kind", "consumed", "schema_version"}
    assert not field_names.intersection(
        {"conversation", "message", "prompt", "response", "screenshot"}
    )


def test_subscription_status_is_authenticated_server_owned_and_not_cached(
    api_client: TestClient,
    auth_a: dict[str, str],
) -> None:
    response = api_client.get("/api/v1/subscription/status", headers=auth_a)

    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store, max-age=0"
    payload = response.json()
    assert payload["schema_version"] == "subscription-status.v1"
    assert payload["plan_code"] == "welcome"
    assert payload["plan_status"] == "active"
    assert payload["purchase_enabled"] is False
    assert {item["kind"] for item in payload["allowances"]} == {
        kind.value for kind in AllowanceKind
    }
