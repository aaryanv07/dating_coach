"""Immutable, content-free subscription contracts."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal


class SubscriptionPlanCode(StrEnum):
    WELCOME = "welcome"
    FREE = "free"
    PLUS = "plus"


class BillingPeriod(StrEnum):
    MONTHLY = "monthly"
    YEARLY = "yearly"


class AllowanceKind(StrEnum):
    CONVERSATION_ANALYSIS = "conversation_analysis"
    REPLY_GENERATION = "reply_generation"
    FIRST_MESSAGE_GENERATION = "first_message_generation"
    PROGRESS_INSIGHT = "progress_insight"


class AllowanceResetPeriod(StrEnum):
    WELCOME_WINDOW = "welcome_window"
    MONTHLY = "monthly"
    WEEKLY = "weekly"


class NonPaywalledCapability(StrEnum):
    SAFETY_GUIDANCE = "safety_guidance"
    PRIVACY_CONTROLS = "privacy_controls"
    VIEW_EXISTING_RESULTS = "view_existing_results"
    DATA_EXPORT = "data_export"
    DATA_DELETION = "data_deletion"
    ACCOUNT_DELETION = "account_deletion"


@dataclass(frozen=True, slots=True)
class StorePriceV1:
    """Reference price in minor currency units; storefront data remains authoritative."""

    amount_minor: int
    billing_period: BillingPeriod
    currency: Literal["INR"] = "INR"
    schema_version: Literal["store-price.v1"] = "store-price.v1"

    def __post_init__(self) -> None:
        if self.amount_minor <= 0:
            raise ValueError("store price must be positive")


@dataclass(frozen=True, slots=True)
class PlanAllowanceV1:
    kind: AllowanceKind
    limit: int
    reset_period: AllowanceResetPeriod
    schema_version: Literal["plan-allowance.v1"] = "plan-allowance.v1"

    def __post_init__(self) -> None:
        if self.limit <= 0:
            raise ValueError("allowance limit must be positive")


@dataclass(frozen=True, slots=True)
class SubscriptionPlanV1:
    code: SubscriptionPlanCode
    display_name: str
    prices: tuple[StorePriceV1, ...]
    allowances: tuple[PlanAllowanceV1, ...]
    non_paywalled_capabilities: tuple[NonPaywalledCapability, ...]
    purchase_enabled: bool = False
    schema_version: Literal["subscription-plan.v1"] = "subscription-plan.v1"

    def __post_init__(self) -> None:
        if not self.display_name.strip():
            raise ValueError("plan display name must not be blank")
        if len({price.billing_period for price in self.prices}) != len(self.prices):
            raise ValueError("plan billing periods must be unique")
        allowance_kinds = tuple(allowance.kind for allowance in self.allowances)
        if set(allowance_kinds) != set(AllowanceKind):
            raise ValueError("plan must define every allowance exactly once")
        if len(set(allowance_kinds)) != len(allowance_kinds):
            raise ValueError("plan allowance kinds must be unique")
        if set(self.non_paywalled_capabilities) != set(NonPaywalledCapability):
            raise ValueError("plan must preserve every non-paywalled capability")
        if len(set(self.non_paywalled_capabilities)) != len(self.non_paywalled_capabilities):
            raise ValueError("non-paywalled capabilities must be unique")
        if self.code == SubscriptionPlanCode.PLUS and not self.prices:
            raise ValueError("Plus must define reference prices")
        if self.code != SubscriptionPlanCode.PLUS and self.prices:
            raise ValueError("non-paid plans must not define store prices")
        if self.purchase_enabled and self.code != SubscriptionPlanCode.PLUS:
            raise ValueError("only Plus can be store-purchased")


@dataclass(frozen=True, slots=True)
class AllowanceConsumptionV1:
    kind: AllowanceKind
    consumed: int
    schema_version: Literal["allowance-consumption.v1"] = "allowance-consumption.v1"

    def __post_init__(self) -> None:
        if self.consumed < 0:
            raise ValueError("allowance consumption must not be negative")


@dataclass(frozen=True, slots=True)
class AllowanceDecisionV1:
    kind: AllowanceKind
    limit: int
    consumed: int
    remaining: int
    request_allowed: bool
    reset_period: AllowanceResetPeriod
    schema_version: Literal["allowance-decision.v1"] = "allowance-decision.v1"

    def __post_init__(self) -> None:
        if self.limit <= 0 or self.consumed < 0 or self.remaining < 0:
            raise ValueError("allowance decision values are invalid")
        expected_remaining = max(self.limit - self.consumed, 0)
        if self.remaining != expected_remaining:
            raise ValueError("allowance decision remaining value is inconsistent")
        if self.request_allowed != (self.remaining > 0):
            raise ValueError("allowance decision state is inconsistent")
