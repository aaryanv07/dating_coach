"""Owner-safe persistence for server-verified store entitlements."""

from hashlib import sha256
from hmac import new as hmac_new
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import SubscriptionEntitlement, User, utc_now
from app.subscriptions.store_verification import VerifiedStorePurchase


class EntitlementPersistenceError(ValueError):
    """Stable failure that never includes a raw store transaction reference."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


class StoreEntitlementRepository:
    def __init__(self, session: AsyncSession, *, hash_secret: str) -> None:
        if len(hash_secret) < 32:
            raise EntitlementPersistenceError("entitlement_hash_secret_invalid")
        self._session = session
        self._secret = hash_secret.encode("utf-8")

    async def apply(self, purchase: VerifiedStorePurchase) -> SubscriptionEntitlement:
        user = await self._session.scalar(
            select(User).where(User.id == purchase.account_reference).with_for_update()
        )
        if user is None or user.deleted_at is not None:
            raise EntitlementPersistenceError("purchase_account_unavailable")
        reference_hash = self._reference_hash(
            storefront=purchase.storefront.value,
            reference=purchase.transaction_reference,
        )
        entitlement = await self._session.scalar(
            select(SubscriptionEntitlement)
            .where(
                SubscriptionEntitlement.storefront == purchase.storefront.value,
                SubscriptionEntitlement.transaction_reference_hash == reference_hash,
            )
            .with_for_update()
        )
        if entitlement is not None and entitlement.user_id != purchase.account_reference:
            raise EntitlementPersistenceError("purchase_already_linked")
        if entitlement is None:
            entitlement = SubscriptionEntitlement(
                user_id=purchase.account_reference,
                plan_code="plus",
                storefront=purchase.storefront.value,
                transaction_reference_hash=reference_hash,
                status=purchase.status.value,
                current_period_start=purchase.period_start,
                current_period_end=purchase.period_end,
                verified_at=utc_now(),
            )
            self._session.add(entitlement)
        else:
            entitlement.status = purchase.status.value
            entitlement.current_period_start = purchase.period_start
            entitlement.current_period_end = purchase.period_end
            entitlement.verified_at = utc_now()
        await self._session.commit()
        return entitlement

    def _reference_hash(self, *, storefront: str, reference: str) -> str:
        material = f"{storefront}\0{reference}".encode()
        return hmac_new(self._secret, material, sha256).hexdigest()


async def user_exists(session: AsyncSession, user_id: UUID) -> bool:
    """Content-free helper used by webhook processing tests and diagnostics."""
    return await session.scalar(select(User.id).where(User.id == user_id)) is not None
