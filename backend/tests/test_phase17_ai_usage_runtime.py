"""Phase 17 server-owned allowance, idempotency, and cost guard tests."""

from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import Base
from app.db.models import Conversation, SubscriptionEntitlement, User
from app.db.session import create_database_engine, create_session_factory
from app.subscriptions.contracts import AllowanceKind, SubscriptionPlanCode
from app.subscriptions.runtime import (
    AIUsageRepository,
    UsagePolicy,
    UsageRuntimeFailure,
    UsageRuntimeFailureCode,
)


def _policy(
    *,
    rate_limit: int = 60,
    reservation_cost: int = 100,
    user_budget: int = 10_000_000,
    global_budget: int = 100_000_000,
    input_price: int = 2_500_000,
    output_price: int = 15_000_000,
) -> UsagePolicy:
    return UsagePolicy(
        new_requests_per_minute=rate_limit,
        reservation_cost_microusd=reservation_cost,
        user_monthly_budget_microusd=user_budget,
        global_monthly_budget_microusd=global_budget,
        input_price_microusd_per_million_tokens=input_price,
        output_price_microusd_per_million_tokens=output_price,
    )


@pytest.fixture
async def usage_session(tmp_path: Path) -> AsyncIterator[AsyncSession]:
    engine = create_database_engine(f"sqlite+aiosqlite:///{tmp_path / 'usage.db'}")
    session_factory = create_session_factory(engine)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with session_factory() as session:
        yield session
    await engine.dispose()


async def _owner_and_conversation(
    usage_session: AsyncSession,
) -> tuple[User, Conversation, datetime]:
    now = datetime.now(UTC)
    user = User(
        auth_subject=f"subject-{uuid4()}",
        created_at=now - timedelta(days=1),
        updated_at=now - timedelta(days=1),
    )
    conversation = Conversation(
        owner=user,
        title="Synthetic reviewed conversation",
        source_type="paste",
        status="confirmed",
    )
    usage_session.add_all((user, conversation))
    await usage_session.commit()
    return user, conversation, now


@pytest.mark.anyio
async def test_reservation_completion_release_and_idempotency_are_atomic(
    usage_session: AsyncSession,
) -> None:
    user, conversation, now = await _owner_and_conversation(usage_session)
    repository = AIUsageRepository(usage_session, _policy())
    key = str(uuid4())
    fingerprint = "a" * 64

    reservation = await repository.reserve_conversation_analysis(
        user_id=user.id,
        conversation_id=conversation.id,
        idempotency_key=key,
        request_fingerprint=fingerprint,
        model_identifier="gpt-5.6-terra",
        correlation_id=uuid4(),
        now=now,
    )
    assert reservation.allowance.reserved == 1
    assert reservation.allowance.remaining == 4

    with pytest.raises(UsageRuntimeFailure) as in_progress:
        await repository.reserve_conversation_analysis(
            user_id=user.id,
            conversation_id=conversation.id,
            idempotency_key=key,
            request_fingerprint=fingerprint,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=now,
        )
    assert in_progress.value.code == UsageRuntimeFailureCode.IDEMPOTENCY_IN_PROGRESS

    await repository.release(user_id=user.id, record_id=reservation.record_id, now=now)
    retried = await repository.reserve_conversation_analysis(
        user_id=user.id,
        conversation_id=conversation.id,
        idempotency_key=key,
        request_fingerprint=fingerprint,
        model_identifier="gpt-5.6-terra",
        correlation_id=uuid4(),
        now=now,
    )
    completed = await repository.complete(
        user_id=user.id,
        record_id=retried.record_id,
        input_tokens=100,
        output_tokens=50,
        total_tokens=150,
        now=now,
    )
    assert (completed.consumed, completed.reserved, completed.remaining) == (1, 0, 4)
    budget = await repository.budget_snapshot(user_id=user.id, now=now)
    assert budget.user_cost_microusd == 1_000

    with pytest.raises(UsageRuntimeFailure) as replayed:
        await repository.reserve_conversation_analysis(
            user_id=user.id,
            conversation_id=conversation.id,
            idempotency_key=key,
            request_fingerprint=fingerprint,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=now,
        )
    assert replayed.value.code == UsageRuntimeFailureCode.IDEMPOTENCY_REPLAYED

    with pytest.raises(UsageRuntimeFailure) as conflict:
        await repository.reserve_conversation_analysis(
            user_id=user.id,
            conversation_id=conversation.id,
            idempotency_key=key,
            request_fingerprint="b" * 64,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=now,
        )
    assert conflict.value.code == UsageRuntimeFailureCode.IDEMPOTENCY_CONFLICT


@pytest.mark.anyio
async def test_allowance_rate_and_budget_guards_fail_closed(
    usage_session: AsyncSession,
) -> None:
    user, conversation, now = await _owner_and_conversation(usage_session)
    allowance_repository = AIUsageRepository(usage_session, _policy())
    for index in range(5):
        reservation = await allowance_repository.reserve_conversation_analysis(
            user_id=user.id,
            conversation_id=conversation.id,
            idempotency_key=str(uuid4()),
            request_fingerprint=f"{index:064d}",
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=now,
        )
        await allowance_repository.complete(
            user_id=user.id,
            record_id=reservation.record_id,
            input_tokens=1,
            output_tokens=0,
            total_tokens=1,
            now=now,
        )
    with pytest.raises(UsageRuntimeFailure) as exhausted:
        await allowance_repository.reserve_conversation_analysis(
            user_id=user.id,
            conversation_id=conversation.id,
            idempotency_key=str(uuid4()),
            request_fingerprint="f" * 64,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=now,
        )
    assert exhausted.value.code == UsageRuntimeFailureCode.ALLOWANCE_EXHAUSTED

    second_user, second_conversation, second_now = await _owner_and_conversation(usage_session)
    rate_repository = AIUsageRepository(usage_session, _policy(rate_limit=1))
    first = await rate_repository.reserve_conversation_analysis(
        user_id=second_user.id,
        conversation_id=second_conversation.id,
        idempotency_key=str(uuid4()),
        request_fingerprint="1" * 64,
        model_identifier="gpt-5.6-terra",
        correlation_id=uuid4(),
        now=second_now,
    )
    await rate_repository.release(
        user_id=second_user.id,
        record_id=first.record_id,
        now=second_now,
    )
    with pytest.raises(UsageRuntimeFailure) as rate_limited:
        await rate_repository.reserve_conversation_analysis(
            user_id=second_user.id,
            conversation_id=second_conversation.id,
            idempotency_key=str(uuid4()),
            request_fingerprint="2" * 64,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=second_now,
        )
    assert rate_limited.value.code == UsageRuntimeFailureCode.RATE_LIMITED

    third_user, third_conversation, third_now = await _owner_and_conversation(usage_session)
    budget_repository = AIUsageRepository(
        usage_session,
        _policy(
            reservation_cost=100,
            user_budget=150,
            input_price=100_000_000,
        ),
    )
    billable = await budget_repository.reserve_conversation_analysis(
        user_id=third_user.id,
        conversation_id=third_conversation.id,
        idempotency_key=str(uuid4()),
        request_fingerprint="3" * 64,
        model_identifier="gpt-5.6-terra",
        correlation_id=uuid4(),
        now=third_now,
    )
    await budget_repository.complete(
        user_id=third_user.id,
        record_id=billable.record_id,
        input_tokens=1,
        output_tokens=0,
        total_tokens=1,
        now=third_now,
    )
    with pytest.raises(UsageRuntimeFailure) as budget_exhausted:
        await budget_repository.reserve_conversation_analysis(
            user_id=third_user.id,
            conversation_id=third_conversation.id,
            idempotency_key=str(uuid4()),
            request_fingerprint="4" * 64,
            model_identifier="gpt-5.6-terra",
            correlation_id=uuid4(),
            now=third_now,
        )
    assert budget_exhausted.value.code == UsageRuntimeFailureCode.BUDGET_EXHAUSTED


@pytest.mark.anyio
async def test_verified_paid_entitlement_selects_plus_server_side(
    usage_session: AsyncSession,
) -> None:
    user, _, now = await _owner_and_conversation(usage_session)
    usage_session.add(
        SubscriptionEntitlement(
            user_id=user.id,
            plan_code="plus",
            status="active",
            storefront="admin",
            transaction_reference_hash="c" * 64,
            current_period_start=now - timedelta(days=3),
            current_period_end=now + timedelta(days=27),
        )
    )
    await usage_session.commit()

    snapshots = await AIUsageRepository(usage_session, _policy()).all_allowances(
        user_id=user.id,
        now=now,
    )

    assert {snapshot.plan_code for snapshot in snapshots} == {SubscriptionPlanCode.PLUS}
    conversation_allowance = next(
        item for item in snapshots if item.kind == AllowanceKind.CONVERSATION_ANALYSIS
    )
    assert conversation_allowance.limit == 12
