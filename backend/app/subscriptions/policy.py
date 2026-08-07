"""Pure allowance evaluation with no reservation or persistence behavior."""

from app.subscriptions.contracts import (
    AllowanceConsumptionV1,
    AllowanceDecisionV1,
    SubscriptionPlanV1,
)


def evaluate_allowance(
    plan: SubscriptionPlanV1,
    consumption: AllowanceConsumptionV1,
) -> AllowanceDecisionV1:
    allowance = next(item for item in plan.allowances if item.kind == consumption.kind)
    remaining = max(allowance.limit - consumption.consumed, 0)
    return AllowanceDecisionV1(
        kind=allowance.kind,
        limit=allowance.limit,
        consumed=consumption.consumed,
        remaining=remaining,
        request_allowed=remaining > 0,
        reset_period=allowance.reset_period,
    )
