"""Closed subscription catalog; storefront availability remains runtime-gated."""

from app.subscriptions.contracts import (
    AllowanceKind,
    AllowanceResetPeriod,
    BillingPeriod,
    NonPaywalledCapability,
    PlanAllowanceV1,
    StorePriceV1,
    SubscriptionPlanCode,
    SubscriptionPlanV1,
)

SUBSCRIPTION_CATALOG_VERSION = "subscription-catalog.v1"

_PROTECTED_CAPABILITIES = tuple(NonPaywalledCapability)


def _allowances(
    *,
    conversation_analyses: int,
    reply_generations: int,
    first_message_generations: int,
    progress_insights: int,
    default_reset: AllowanceResetPeriod,
    progress_reset: AllowanceResetPeriod,
) -> tuple[PlanAllowanceV1, ...]:
    return (
        PlanAllowanceV1(
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            limit=conversation_analyses,
            reset_period=default_reset,
        ),
        PlanAllowanceV1(
            kind=AllowanceKind.REPLY_GENERATION,
            limit=reply_generations,
            reset_period=default_reset,
        ),
        PlanAllowanceV1(
            kind=AllowanceKind.FIRST_MESSAGE_GENERATION,
            limit=first_message_generations,
            reset_period=default_reset,
        ),
        PlanAllowanceV1(
            kind=AllowanceKind.PROGRESS_INSIGHT,
            limit=progress_insights,
            reset_period=progress_reset,
        ),
    )


WELCOME_PLAN = SubscriptionPlanV1(
    code=SubscriptionPlanCode.WELCOME,
    display_name="30-day welcome allowance",
    prices=(),
    allowances=_allowances(
        conversation_analyses=5,
        reply_generations=25,
        first_message_generations=5,
        progress_insights=4,
        default_reset=AllowanceResetPeriod.WELCOME_WINDOW,
        progress_reset=AllowanceResetPeriod.WEEKLY,
    ),
    non_paywalled_capabilities=_PROTECTED_CAPABILITIES,
)

FREE_PLAN = SubscriptionPlanV1(
    code=SubscriptionPlanCode.FREE,
    display_name="Free",
    prices=(),
    allowances=_allowances(
        conversation_analyses=2,
        reply_generations=10,
        first_message_generations=3,
        progress_insights=1,
        default_reset=AllowanceResetPeriod.MONTHLY,
        progress_reset=AllowanceResetPeriod.MONTHLY,
    ),
    non_paywalled_capabilities=_PROTECTED_CAPABILITIES,
)

PLUS_PLAN = SubscriptionPlanV1(
    code=SubscriptionPlanCode.PLUS,
    display_name="ConvoCoach Plus",
    prices=(
        StorePriceV1(amount_minor=99_900, billing_period=BillingPeriod.MONTHLY),
        StorePriceV1(amount_minor=899_900, billing_period=BillingPeriod.YEARLY),
    ),
    allowances=_allowances(
        conversation_analyses=12,
        reply_generations=80,
        first_message_generations=10,
        progress_insights=4,
        default_reset=AllowanceResetPeriod.MONTHLY,
        progress_reset=AllowanceResetPeriod.WEEKLY,
    ),
    non_paywalled_capabilities=_PROTECTED_CAPABILITIES,
    purchase_enabled=True,
)

SUBSCRIPTION_CATALOG = (WELCOME_PLAN, FREE_PLAN, PLUS_PLAN)


def plan_for(code: SubscriptionPlanCode) -> SubscriptionPlanV1:
    """Return one closed-catalog plan or fail instead of silently defaulting."""
    for plan in SUBSCRIPTION_CATALOG:
        if plan.code == code:
            return plan
    raise LookupError(f"unsupported subscription plan: {code}")
