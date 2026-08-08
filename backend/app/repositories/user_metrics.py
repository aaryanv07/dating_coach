"""Aggregate-only operator metrics over server-owned account records."""

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import and_, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AIUsageRecord, SubscriptionEntitlement, User


@dataclass(frozen=True, slots=True)
class UserMetricsSnapshot:
    """Content-free aggregate counts evaluated at one instant."""

    total_registered_accounts: int
    active_accounts: int
    deleted_accounts: int
    new_registered_accounts_7d: int
    new_registered_accounts_30d: int
    paid_active_accounts: int
    free_active_accounts: int
    ai_active_accounts_24h: int
    ai_active_accounts_7d: int
    ai_active_accounts_30d: int


class UserMetricsRepository:
    """Read aggregate account metrics without loading any identity or message row."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def snapshot(self, *, evaluated_at: datetime) -> UserMetricsSnapshot:
        total_registered = await self._count_users()
        active_accounts = await self._count_users(active_only=True)
        new_7d = await self._count_users(created_since=evaluated_at - timedelta(days=7))
        new_30d = await self._count_users(created_since=evaluated_at - timedelta(days=30))
        paid_active = await self._count_paid_active(evaluated_at=evaluated_at)
        ai_active_24h = await self._count_ai_active(
            created_since=evaluated_at - timedelta(hours=24)
        )
        ai_active_7d = await self._count_ai_active(created_since=evaluated_at - timedelta(days=7))
        ai_active_30d = await self._count_ai_active(created_since=evaluated_at - timedelta(days=30))
        return UserMetricsSnapshot(
            total_registered_accounts=total_registered,
            active_accounts=active_accounts,
            deleted_accounts=total_registered - active_accounts,
            new_registered_accounts_7d=new_7d,
            new_registered_accounts_30d=new_30d,
            paid_active_accounts=paid_active,
            free_active_accounts=active_accounts - paid_active,
            ai_active_accounts_24h=ai_active_24h,
            ai_active_accounts_7d=ai_active_7d,
            ai_active_accounts_30d=ai_active_30d,
        )

    async def _count_users(
        self,
        *,
        active_only: bool = False,
        created_since: datetime | None = None,
    ) -> int:
        statement = select(func.count(User.id))
        if active_only:
            statement = statement.where(User.deleted_at.is_(None))
        if created_since is not None:
            statement = statement.where(User.created_at >= created_since)
        return int(await self._session.scalar(statement) or 0)

    async def _count_paid_active(self, *, evaluated_at: datetime) -> int:
        statement = (
            select(func.count(distinct(SubscriptionEntitlement.user_id)))
            .join(User, User.id == SubscriptionEntitlement.user_id)
            .where(
                User.deleted_at.is_(None),
                SubscriptionEntitlement.status.in_(("active", "grace")),
                SubscriptionEntitlement.current_period_start <= evaluated_at,
                SubscriptionEntitlement.current_period_end > evaluated_at,
            )
        )
        return int(await self._session.scalar(statement) or 0)

    async def _count_ai_active(self, *, created_since: datetime) -> int:
        statement = (
            select(func.count(distinct(AIUsageRecord.user_id)))
            .join(User, User.id == AIUsageRecord.user_id)
            .where(
                and_(
                    User.deleted_at.is_(None),
                    AIUsageRecord.status == "completed",
                    AIUsageRecord.completed_at.is_not(None),
                    AIUsageRecord.completed_at >= created_since,
                )
            )
        )
        return int(await self._session.scalar(statement) or 0)
