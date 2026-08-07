"""Atomic, content-free subscription allowance and AI cost enforcement."""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import cast
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.db.models import AIUsageRecord, SubscriptionEntitlement, User, utc_now
from app.subscriptions.catalog import plan_for
from app.subscriptions.contracts import (
    AllowanceKind,
    AllowanceResetPeriod,
    SubscriptionPlanCode,
)

SUBSCRIPTION_RUNTIME_VERSION = "subscription-runtime.v1"
_ACTIVE_USAGE_STATES = ("reserved", "completed")
_ACTIVE_ENTITLEMENT_STATES = ("active", "grace")


class UsageRuntimeFailureCode(StrEnum):
    IDEMPOTENCY_CONFLICT = "idempotency_conflict"
    IDEMPOTENCY_IN_PROGRESS = "idempotency_in_progress"
    IDEMPOTENCY_REPLAYED = "idempotency_replayed"
    ALLOWANCE_EXHAUSTED = "allowance_exhausted"
    RATE_LIMITED = "rate_limited"
    BUDGET_EXHAUSTED = "budget_exhausted"
    USAGE_UNAVAILABLE = "usage_unavailable"


@dataclass(frozen=True, slots=True)
class UsageRuntimeFailure(Exception):
    """Stable content-free usage enforcement failure."""

    code: UsageRuntimeFailureCode
    retryable: bool = False


@dataclass(frozen=True, slots=True)
class ModelTokenPrice:
    """One exact provider model's server-owned uncached list prices."""

    model_identifier: str
    input_microusd_per_million_tokens: int
    output_microusd_per_million_tokens: int

    def validate(self) -> None:
        if (
            not self.model_identifier
            or len(self.model_identifier) > 64
            or self.model_identifier != self.model_identifier.strip()
            or self.input_microusd_per_million_tokens <= 0
            or self.output_microusd_per_million_tokens <= 0
        ):
            raise ValueError("model_token_price_invalid")


@dataclass(frozen=True, slots=True)
class UsagePolicy:
    """Server-owned prices, retry caps, and budget ceilings."""

    new_requests_per_minute: int
    reservation_cost_microusd: int
    user_monthly_budget_microusd: int
    global_monthly_budget_microusd: int
    input_price_microusd_per_million_tokens: int
    output_price_microusd_per_million_tokens: int
    model_prices: tuple[ModelTokenPrice, ...] = ()

    def validate(self) -> None:
        values = (
            self.new_requests_per_minute,
            self.reservation_cost_microusd,
            self.user_monthly_budget_microusd,
            self.global_monthly_budget_microusd,
            self.input_price_microusd_per_million_tokens,
            self.output_price_microusd_per_million_tokens,
        )
        if any(value <= 0 for value in values):
            raise ValueError("usage_policy_invalid")
        if self.user_monthly_budget_microusd > self.global_monthly_budget_microusd:
            raise ValueError("usage_policy_budget_order_invalid")
        for price in self.model_prices:
            price.validate()
        if len({price.model_identifier for price in self.model_prices}) != len(self.model_prices):
            raise ValueError("usage_policy_model_price_duplicate")

    def prices_for(self, model_identifier: str | None) -> tuple[int, int]:
        if model_identifier is not None:
            for price in self.model_prices:
                if price.model_identifier == model_identifier:
                    return (
                        price.input_microusd_per_million_tokens,
                        price.output_microusd_per_million_tokens,
                    )
            if self.model_prices:
                raise ValueError("usage_policy_model_price_missing")
        return (
            self.input_price_microusd_per_million_tokens,
            self.output_price_microusd_per_million_tokens,
        )


@dataclass(frozen=True, slots=True)
class AllowanceSnapshot:
    plan_code: SubscriptionPlanCode
    plan_status: str
    kind: AllowanceKind
    limit: int
    consumed: int
    reserved: int
    remaining: int
    reset_at: datetime
    server_version: str = SUBSCRIPTION_RUNTIME_VERSION


@dataclass(frozen=True, slots=True)
class UsageReservation:
    record_id: UUID
    allowance: AllowanceSnapshot
    model_identifier: str


@dataclass(frozen=True, slots=True)
class BudgetSnapshot:
    """Content-free current-month AI cost totals and server ceilings."""

    user_cost_microusd: int
    user_budget_microusd: int
    global_cost_microusd: int
    global_budget_microusd: int


@dataclass(frozen=True, slots=True)
class _EffectivePlan:
    code: SubscriptionPlanCode
    status: str
    anchor_start: datetime
    anchor_end: datetime | None


class AIUsageRepository:
    """Reserve before provider execution and release every safe failure."""

    def __init__(self, session: AsyncSession, policy: UsagePolicy) -> None:
        policy.validate()
        self._session = session
        self._policy = policy

    async def reserve_conversation_analysis(
        self,
        *,
        user_id: UUID,
        conversation_id: UUID,
        idempotency_key: str,
        request_fingerprint: str,
        model_identifier: str | None = None,
        model_identifiers_by_plan: Mapping[SubscriptionPlanCode, str] | None = None,
        correlation_id: UUID,
        now: datetime | None = None,
    ) -> UsageReservation:
        evaluated_at = _aware(now or utc_now())
        # Every reservation locks the same first user row before its owner row.
        # PostgreSQL therefore serializes the global budget check across users,
        # while the consistent lock order avoids owner/global deadlocks. The
        # current-user dependency guarantees at least one user exists.
        global_guard_id = await self._session.scalar(
            select(User.id).order_by(User.id).limit(1).with_for_update()
        )
        if global_guard_id is None:
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
        user = await self._session.scalar(select(User).where(User.id == user_id).with_for_update())
        if user is None:
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)

        existing = await self._session.scalar(
            select(AIUsageRecord).where(
                AIUsageRecord.user_id == user_id,
                AIUsageRecord.allowance_kind == AllowanceKind.CONVERSATION_ANALYSIS.value,
                AIUsageRecord.idempotency_key == idempotency_key,
            )
        )
        if existing is not None:
            if existing.request_fingerprint != request_fingerprint:
                raise UsageRuntimeFailure(UsageRuntimeFailureCode.IDEMPOTENCY_CONFLICT)
            if existing.status == "completed":
                raise UsageRuntimeFailure(UsageRuntimeFailureCode.IDEMPOTENCY_REPLAYED)
            if existing.status == "reserved":
                raise UsageRuntimeFailure(
                    UsageRuntimeFailureCode.IDEMPOTENCY_IN_PROGRESS,
                    retryable=True,
                )
            if existing.attempt_count >= 3:
                raise UsageRuntimeFailure(UsageRuntimeFailureCode.RATE_LIMITED)

        plan = await self._effective_plan(user, evaluated_at)
        if (model_identifier is None) == (model_identifiers_by_plan is None):
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
        selected_model_identifier = model_identifier
        if model_identifiers_by_plan is not None:
            selected_model_identifier = model_identifiers_by_plan.get(plan.code)
        if (
            selected_model_identifier is None
            or not selected_model_identifier
            or len(selected_model_identifier) > 64
            or selected_model_identifier != selected_model_identifier.strip()
        ):
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
        window_start, window_end = self._allowance_window(
            plan,
            AllowanceKind.CONVERSATION_ANALYSIS,
            evaluated_at,
        )
        allowance = next(
            item
            for item in plan_for(plan.code).allowances
            if item.kind == AllowanceKind.CONVERSATION_ANALYSIS
        )
        consumed, reserved = await self._usage_counts(
            user_id=user_id,
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            window_start=window_start,
            window_end=window_end,
        )
        if consumed + reserved >= allowance.limit:
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.ALLOWANCE_EXHAUSTED)

        if existing is None:
            recent_requests = int(
                await self._session.scalar(
                    select(func.count(AIUsageRecord.id)).where(
                        AIUsageRecord.user_id == user_id,
                        AIUsageRecord.created_at >= evaluated_at - timedelta(minutes=1),
                    )
                )
                or 0
            )
            if recent_requests >= self._policy.new_requests_per_minute:
                raise UsageRuntimeFailure(
                    UsageRuntimeFailureCode.RATE_LIMITED,
                    retryable=True,
                )

        await self._enforce_budgets(user_id=user_id, now=evaluated_at)
        if existing is None:
            record = AIUsageRecord(
                user_id=user_id,
                conversation_id=conversation_id,
                allowance_kind=AllowanceKind.CONVERSATION_ANALYSIS.value,
                idempotency_key=idempotency_key,
                request_fingerprint=request_fingerprint,
                status="reserved",
                plan_code=plan.code.value,
                window_start=window_start,
                window_end=window_end,
                model_identifier=selected_model_identifier,
                correlation_id=correlation_id,
                attempt_count=1,
                cost_microusd=self._policy.reservation_cost_microusd,
            )
            self._session.add(record)
        else:
            record = existing
            record.status = "reserved"
            record.plan_code = plan.code.value
            record.window_start = window_start
            record.window_end = window_end
            record.model_identifier = selected_model_identifier
            record.correlation_id = correlation_id
            record.attempt_count += 1
            record.cost_microusd = self._policy.reservation_cost_microusd
            record.released_at = None
            record.updated_at = evaluated_at
        await self._session.commit()
        return UsageReservation(
            record_id=record.id,
            model_identifier=selected_model_identifier,
            allowance=AllowanceSnapshot(
                plan_code=plan.code,
                plan_status=plan.status,
                kind=AllowanceKind.CONVERSATION_ANALYSIS,
                limit=allowance.limit,
                consumed=consumed,
                reserved=reserved + 1,
                remaining=max(allowance.limit - consumed - reserved - 1, 0),
                reset_at=window_end,
            ),
        )

    async def complete(
        self,
        *,
        user_id: UUID,
        record_id: UUID,
        input_tokens: int,
        output_tokens: int,
        total_tokens: int,
        now: datetime | None = None,
    ) -> AllowanceSnapshot:
        evaluated_at = _aware(now or utc_now())
        record = await self._owned_record(user_id, record_id)
        if record is None or record.status != "reserved":
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
        record.status = "completed"
        record.input_tokens = input_tokens
        record.output_tokens = output_tokens
        record.total_tokens = total_tokens
        record.cost_microusd = self.estimated_cost_microusd(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            model_identifier=record.model_identifier,
        )
        record.completed_at = evaluated_at
        record.updated_at = evaluated_at
        await self._session.commit()
        return await self.allowance_snapshot(
            user_id=user_id,
            kind=AllowanceKind.CONVERSATION_ANALYSIS,
            now=evaluated_at,
        )

    async def release(
        self,
        *,
        user_id: UUID,
        record_id: UUID,
        now: datetime | None = None,
    ) -> None:
        record = await self._owned_record(user_id, record_id)
        if record is None or record.status != "reserved":
            return
        evaluated_at = _aware(now or utc_now())
        record.status = "released"
        record.cost_microusd = 0
        record.released_at = evaluated_at
        record.updated_at = evaluated_at
        await self._session.commit()

    async def allowance_snapshot(
        self,
        *,
        user_id: UUID,
        kind: AllowanceKind,
        now: datetime | None = None,
    ) -> AllowanceSnapshot:
        evaluated_at = _aware(now or utc_now())
        user = await self._session.scalar(select(User).where(User.id == user_id))
        if user is None:
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
        plan = await self._effective_plan(user, evaluated_at)
        window_start, window_end = self._allowance_window(plan, kind, evaluated_at)
        allowance = next(item for item in plan_for(plan.code).allowances if item.kind == kind)
        consumed, reserved = await self._usage_counts(
            user_id=user_id,
            kind=kind,
            window_start=window_start,
            window_end=window_end,
        )
        return AllowanceSnapshot(
            plan_code=plan.code,
            plan_status=plan.status,
            kind=kind,
            limit=allowance.limit,
            consumed=consumed,
            reserved=reserved,
            remaining=max(allowance.limit - consumed - reserved, 0),
            reset_at=window_end,
        )

    async def all_allowances(
        self,
        *,
        user_id: UUID,
        now: datetime | None = None,
    ) -> tuple[AllowanceSnapshot, ...]:
        return tuple(
            [
                await self.allowance_snapshot(user_id=user_id, kind=kind, now=now)
                for kind in AllowanceKind
            ]
        )

    def estimated_cost_microusd(
        self,
        *,
        input_tokens: int,
        output_tokens: int,
        model_identifier: str | None = None,
    ) -> int:
        if input_tokens < 0 or output_tokens < 0:
            raise ValueError("token_count_invalid")
        input_price, output_price = self._policy.prices_for(model_identifier)
        total = (input_tokens * input_price + output_tokens * output_price) / 1_000_000
        return math.ceil(total)

    async def budget_snapshot(
        self,
        *,
        user_id: UUID,
        now: datetime | None = None,
    ) -> BudgetSnapshot:
        user_cost, global_cost = await self._cost_totals(
            user_id=user_id,
            now=_aware(now or utc_now()),
        )
        return BudgetSnapshot(
            user_cost_microusd=user_cost,
            user_budget_microusd=self._policy.user_monthly_budget_microusd,
            global_cost_microusd=global_cost,
            global_budget_microusd=self._policy.global_monthly_budget_microusd,
        )

    async def _effective_plan(self, user: User, now: datetime) -> _EffectivePlan:
        entitlement = await self._session.scalar(
            select(SubscriptionEntitlement)
            .where(
                SubscriptionEntitlement.user_id == user.id,
                SubscriptionEntitlement.status.in_(_ACTIVE_ENTITLEMENT_STATES),
                SubscriptionEntitlement.current_period_start <= now,
                SubscriptionEntitlement.current_period_end > now,
            )
            .order_by(SubscriptionEntitlement.current_period_end.desc())
            .limit(1)
        )
        if entitlement is not None:
            return _EffectivePlan(
                code=SubscriptionPlanCode.PLUS,
                status=entitlement.status,
                anchor_start=_aware(entitlement.current_period_start),
                anchor_end=_aware(entitlement.current_period_end),
            )
        welcome_start = _aware(user.created_at)
        welcome_end = welcome_start + timedelta(days=30)
        if now < welcome_end:
            return _EffectivePlan(
                code=SubscriptionPlanCode.WELCOME,
                status="active",
                anchor_start=welcome_start,
                anchor_end=welcome_end,
            )
        return _EffectivePlan(
            code=SubscriptionPlanCode.FREE,
            status="active",
            anchor_start=now,
            anchor_end=None,
        )

    def _allowance_window(
        self,
        plan: _EffectivePlan,
        kind: AllowanceKind,
        now: datetime,
    ) -> tuple[datetime, datetime]:
        allowance = next(item for item in plan_for(plan.code).allowances if item.kind == kind)
        if allowance.reset_period == AllowanceResetPeriod.WELCOME_WINDOW:
            if plan.anchor_end is None:
                raise UsageRuntimeFailure(UsageRuntimeFailureCode.USAGE_UNAVAILABLE)
            return plan.anchor_start, plan.anchor_end
        if allowance.reset_period == AllowanceResetPeriod.WEEKLY:
            elapsed_days = max((now - plan.anchor_start).days, 0)
            start = plan.anchor_start + timedelta(days=(elapsed_days // 7) * 7)
            end = start + timedelta(days=7)
            if plan.anchor_end is not None:
                end = min(end, plan.anchor_end)
            return start, end
        start = datetime(now.year, now.month, 1, tzinfo=UTC)
        end = (
            datetime(now.year + 1, 1, 1, tzinfo=UTC)
            if now.month == 12
            else datetime(now.year, now.month + 1, 1, tzinfo=UTC)
        )
        if plan.code == SubscriptionPlanCode.PLUS:
            start = max(start, plan.anchor_start)
            if plan.anchor_end is not None:
                end = min(end, plan.anchor_end)
        return start, end

    async def _usage_counts(
        self,
        *,
        user_id: UUID,
        kind: AllowanceKind,
        window_start: datetime,
        window_end: datetime,
    ) -> tuple[int, int]:
        rows = await self._session.execute(
            select(AIUsageRecord.status, func.count(AIUsageRecord.id))
            .where(
                AIUsageRecord.user_id == user_id,
                AIUsageRecord.allowance_kind == kind.value,
                AIUsageRecord.window_start == window_start,
                AIUsageRecord.window_end == window_end,
                AIUsageRecord.status.in_(_ACTIVE_USAGE_STATES),
            )
            .group_by(AIUsageRecord.status)
        )
        counts = {status: int(count) for status, count in rows.all()}
        return counts.get("completed", 0), counts.get("reserved", 0)

    async def _enforce_budgets(self, *, user_id: UUID, now: datetime) -> None:
        user_cost, global_cost = await self._cost_totals(user_id=user_id, now=now)
        reserve = self._policy.reservation_cost_microusd
        if (
            user_cost + reserve > self._policy.user_monthly_budget_microusd
            or global_cost + reserve > self._policy.global_monthly_budget_microusd
        ):
            raise UsageRuntimeFailure(UsageRuntimeFailureCode.BUDGET_EXHAUSTED)

    async def _cost_totals(self, *, user_id: UUID, now: datetime) -> tuple[int, int]:
        start = datetime(now.year, now.month, 1, tzinfo=UTC)
        user_cost = int(
            await self._session.scalar(
                select(func.coalesce(func.sum(AIUsageRecord.cost_microusd), 0)).where(
                    AIUsageRecord.user_id == user_id,
                    AIUsageRecord.created_at >= start,
                    AIUsageRecord.status.in_(_ACTIVE_USAGE_STATES),
                )
            )
            or 0
        )
        global_cost = int(
            await self._session.scalar(
                select(func.coalesce(func.sum(AIUsageRecord.cost_microusd), 0)).where(
                    AIUsageRecord.created_at >= start,
                    AIUsageRecord.status.in_(_ACTIVE_USAGE_STATES),
                )
            )
            or 0
        )
        return user_cost, global_cost

    async def _owned_record(self, user_id: UUID, record_id: UUID) -> AIUsageRecord | None:
        return cast(
            AIUsageRecord | None,
            await self._session.scalar(
                select(AIUsageRecord).where(
                    AIUsageRecord.id == record_id,
                    AIUsageRecord.user_id == user_id,
                )
            ),
        )


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def usage_policy_from_settings(settings: Settings) -> UsagePolicy:
    """Build the usage policy solely from validated server configuration."""
    model_prices: tuple[ModelTokenPrice, ...] = ()
    if settings.ai_provider_mode == "openrouter_tiered":
        input_price = settings.openrouter_paid_input_price_microusd_per_million_tokens
        output_price = settings.openrouter_paid_output_price_microusd_per_million_tokens
        model_prices = (
            ModelTokenPrice(
                model_identifier=settings.openrouter_free_model,
                input_microusd_per_million_tokens=(
                    settings.openrouter_free_input_price_microusd_per_million_tokens
                ),
                output_microusd_per_million_tokens=(
                    settings.openrouter_free_output_price_microusd_per_million_tokens
                ),
            ),
            ModelTokenPrice(
                model_identifier=settings.openrouter_paid_model,
                input_microusd_per_million_tokens=(
                    settings.openrouter_paid_input_price_microusd_per_million_tokens
                ),
                output_microusd_per_million_tokens=(
                    settings.openrouter_paid_output_price_microusd_per_million_tokens
                ),
            ),
        )
    elif settings.ai_provider_mode == "zai_glm":
        input_price = settings.zai_input_price_microusd_per_million_tokens
        output_price = settings.zai_output_price_microusd_per_million_tokens
    else:
        input_price = settings.openai_input_price_microusd_per_million_tokens
        output_price = settings.openai_output_price_microusd_per_million_tokens
    return UsagePolicy(
        new_requests_per_minute=settings.ai_new_requests_per_minute,
        reservation_cost_microusd=settings.ai_reservation_cost_microusd,
        user_monthly_budget_microusd=settings.ai_user_monthly_budget_microusd,
        global_monthly_budget_microusd=settings.ai_global_monthly_budget_microusd,
        input_price_microusd_per_million_tokens=input_price,
        output_price_microusd_per_million_tokens=output_price,
        model_prices=model_prices,
    )
