"""Authenticated subscription status and verified storefront routes."""

from typing import Literal, cast

from fastapi import APIRouter, Header, HTTPException, Request, Response, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.core.config import Settings
from app.db.models import utc_now
from app.schemas.subscriptions import (
    AllowanceStatusV1,
    AppleStoreNotificationV1,
    StorePurchaseContextV1,
    StorePurchaseVerificationRequestV1,
    StorePurchaseVerificationResponseV1,
    SubscriptionStatusV1,
)
from app.subscriptions.entitlements import (
    EntitlementPersistenceError,
    StoreEntitlementRepository,
)
from app.subscriptions.runtime import AIUsageRepository, usage_policy_from_settings
from app.subscriptions.store_verification import (
    StorePurchaseVerifier,
    StoreVerificationError,
)

router = APIRouter(prefix="/api/v1/subscription", tags=["subscription"])


@router.get("/status", response_model=SubscriptionStatusV1)
async def read_subscription_status(
    request: Request,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
) -> SubscriptionStatusV1:
    """Return only the server-owned effective plan and usage counters."""
    settings = cast(Settings, request.app.state.settings)
    snapshots = await AIUsageRepository(
        session,
        usage_policy_from_settings(settings),
    ).all_allowances(user_id=user.id)
    first = snapshots[0]
    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    return SubscriptionStatusV1(
        plan_code=first.plan_code,
        plan_status=cast(Literal["active", "grace"], first.plan_status),
        purchase_enabled=settings.store_billing_enabled,
        allowances=tuple(
            AllowanceStatusV1(
                kind=item.kind,
                limit=item.limit,
                consumed=item.consumed,
                reserved=item.reserved,
                remaining=item.remaining,
                reset_at=item.reset_at,
            )
            for item in snapshots
        ),
        generated_at=utc_now(),
    )


@router.get("/purchase-context", response_model=StorePurchaseContextV1)
async def read_store_purchase_context(
    request: Request,
    response: Response,
    user: CurrentUser,
) -> StorePurchaseContextV1:
    """Return an opaque UUID that storefronts bind to the authenticated owner."""
    settings = cast(Settings, request.app.state.settings)
    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    return StorePurchaseContextV1(
        account_reference=user.id,
        purchase_enabled=settings.store_billing_enabled,
    )


@router.post("/verify", response_model=StorePurchaseVerificationResponseV1)
async def verify_store_purchase(
    payload: StorePurchaseVerificationRequestV1,
    request: Request,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
) -> StorePurchaseVerificationResponseV1:
    """Grant entitlement only after independent server-side store verification."""
    settings = cast(Settings, request.app.state.settings)
    verifier = cast(StorePurchaseVerifier, request.app.state.store_purchase_verifier)
    try:
        purchase = await verifier.verify_purchase(
            storefront=payload.storefront,
            product_id=payload.product_id,
            verification_data=payload.verification_data,
            expected_account_reference=user.id,
        )
        entitlement = await StoreEntitlementRepository(
            session,
            hash_secret=settings.store_transaction_hash_secret,
        ).apply(purchase)
    except StoreVerificationError as error:
        raise _store_http_error(error) from error
    except EntitlementPersistenceError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=error.code) from error
    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    return StorePurchaseVerificationResponseV1(
        plan_status=cast(
            Literal["active", "grace", "expired", "revoked"],
            entitlement.status,
        ),
        current_period_end=entitlement.current_period_end,
    )


@router.post("/notifications/apple", status_code=status.HTTP_204_NO_CONTENT)
async def receive_apple_store_notification(
    payload: AppleStoreNotificationV1,
    request: Request,
    session: DatabaseSession,
) -> Response:
    """Verify App Store Server Notifications V2 before mutating an entitlement."""
    settings = cast(Settings, request.app.state.settings)
    verifier = cast(StorePurchaseVerifier, request.app.state.store_purchase_verifier)
    try:
        notification = await verifier.verify_apple_notification(payload.signedPayload)
        if notification.purchase is not None:
            await StoreEntitlementRepository(
                session,
                hash_secret=settings.store_transaction_hash_secret,
            ).apply(notification.purchase)
    except StoreVerificationError as error:
        raise _store_http_error(error) from error
    except EntitlementPersistenceError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=error.code) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/notifications/google", status_code=status.HTTP_204_NO_CONTENT)
async def receive_google_play_notification(
    payload: dict[str, object],
    request: Request,
    session: DatabaseSession,
    authorization: str = Header(default=""),
) -> Response:
    """Authenticate Pub/Sub and re-query Google before mutating an entitlement."""
    settings = cast(Settings, request.app.state.settings)
    verifier = cast(StorePurchaseVerifier, request.app.state.store_purchase_verifier)
    try:
        notification = await verifier.verify_google_notification(
            authorization=authorization,
            envelope=payload,
        )
        if notification.purchase is not None:
            await StoreEntitlementRepository(
                session,
                hash_secret=settings.store_transaction_hash_secret,
            ).apply(notification.purchase)
    except StoreVerificationError as error:
        raise _store_http_error(error) from error
    except EntitlementPersistenceError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=error.code) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _store_http_error(error: StoreVerificationError) -> HTTPException:
    if error.retryable or error.code.endswith("_unavailable"):
        return HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=error.code,
        )
    if "account_reference_mismatch" in error.code or error.code.endswith("_authentication_failed"):
        return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=error.code)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=error.code)
