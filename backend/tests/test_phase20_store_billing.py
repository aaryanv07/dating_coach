"""Phase 20 store-verification and entitlement regression tests."""

import asyncio
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Any
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine

from app.auth.contracts import AuthClaims
from app.auth.verifier import StaticAuthenticationVerifier
from app.core.config import Settings
from app.db.base import Base
from app.db.session import create_database_engine, create_session_factory
from app.main import create_app
from app.subscriptions.apple_roots import apple_root_certificates
from app.subscriptions.store_verification import (
    Storefront,
    StoreNotification,
    StorePurchaseStatus,
    VerifiedStorePurchase,
    _apple_purchase,
    _google_purchase,
)


async def _create_schema(engine: AsyncEngine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


class _FakeStoreVerifier:
    async def verify_purchase(
        self,
        *,
        storefront: Storefront,
        product_id: str,
        verification_data: str,
        expected_account_reference: UUID,
    ) -> VerifiedStorePurchase:
        del verification_data
        now = datetime.now(UTC)
        return VerifiedStorePurchase(
            storefront=storefront,
            transaction_reference="verified-transaction-1",
            product_id=product_id,
            account_reference=expected_account_reference,
            period_start=now,
            period_end=now + timedelta(days=30),
            status=StorePurchaseStatus.ACTIVE,
        )

    async def verify_apple_notification(self, signed_payload: str) -> StoreNotification:
        del signed_payload
        return StoreNotification(purchase=None, notification_reference="apple-notification")

    async def verify_google_notification(
        self,
        *,
        authorization: str,
        envelope: dict[str, object],
    ) -> StoreNotification:
        del authorization, envelope
        return StoreNotification(purchase=None, notification_reference="google-notification")


@pytest.fixture
def store_client(tmp_path: Path) -> Iterator[TestClient]:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'store.db'}"
    engine = create_database_engine(database_url)

    @event.listens_for(engine.sync_engine, "connect")
    def enable_foreign_keys(dbapi_connection: Any, _: Any) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    asyncio.run(_create_schema(engine))
    verifier = StaticAuthenticationVerifier(
        {
            "token-a": AuthClaims(subject="store-subject-a"),
            "token-b": AuthClaims(subject="store-subject-b"),
        }
    )
    application = create_app(
        Settings(
            app_environment="test",
            database_url=database_url,
            store_transaction_hash_secret="s" * 32,
        ),
        session_factory=create_session_factory(engine),
        auth_verifier=verifier,
        store_purchase_verifier=_FakeStoreVerifier(),
    )
    with TestClient(application) as client:
        yield client
    asyncio.run(engine.dispose())


def test_authenticated_purchase_is_verified_and_activates_plus(
    store_client: TestClient,
) -> None:
    headers = {"Authorization": "Bearer token-a"}
    context = store_client.get("/api/v1/subscription/purchase-context", headers=headers)

    assert context.status_code == 200
    assert UUID(context.json()["account_reference"])
    response = store_client.post(
        "/api/v1/subscription/verify",
        headers=headers,
        json={
            "schema_version": "store-purchase-verification-request.v1",
            "storefront": "apple",
            "product_id": "com.convocoach.plus.monthly",
            "verification_data": "store-signed-evidence",
        },
    )

    assert response.status_code == 200
    assert response.json()["plan_code"] == "plus"
    assert response.json()["plan_status"] == "active"
    status_response = store_client.get("/api/v1/subscription/status", headers=headers)
    assert status_response.json()["plan_code"] == "plus"


def test_same_store_transaction_cannot_be_linked_to_a_second_account(
    store_client: TestClient,
) -> None:
    payload = {
        "schema_version": "store-purchase-verification-request.v1",
        "storefront": "google",
        "product_id": "com.convocoach.plus.monthly",
        "verification_data": "purchase-token",
    }

    first = store_client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": "Bearer token-a"},
        json=payload,
    )
    second = store_client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": "Bearer token-b"},
        json=payload,
    )

    assert first.status_code == 200
    assert second.status_code == 409
    assert second.json()["detail"] == "purchase_already_linked"


def test_unconfigured_store_verifier_fails_closed(api_client: TestClient) -> None:
    response = api_client.post(
        "/api/v1/subscription/verify",
        headers={"Authorization": "Bearer token-a"},
        json={
            "schema_version": "store-purchase-verification-request.v1",
            "storefront": "apple",
            "product_id": "com.convocoach.plus.monthly",
            "verification_data": "untrusted-evidence",
        },
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "store_billing_unavailable"


def test_notification_endpoints_return_no_private_payload(store_client: TestClient) -> None:
    apple = store_client.post(
        "/api/v1/subscription/notifications/apple",
        json={"signedPayload": "signed-notification"},
    )
    google = store_client.post(
        "/api/v1/subscription/notifications/google",
        headers={"Authorization": "Bearer signed-push-token"},
        json={"message": {"messageId": "message-1", "data": "e30="}},
    )

    assert (apple.status_code, apple.content) == (204, b"")
    assert (google.status_code, google.content) == (204, b"")


def test_pinned_apple_roots_have_expected_der_shape() -> None:
    roots = apple_root_certificates()

    assert len(roots) == 2
    assert all(root.startswith(b"0") for root in roots)


def test_apple_projection_requires_matching_account_and_active_period() -> None:
    now = datetime.now(UTC)
    account_id = UUID("11111111-1111-4111-8111-111111111111")
    transaction = SimpleNamespace(
        productId="com.convocoach.plus.monthly",
        originalTransactionId="original-1",
        transactionId="transaction-1",
        appAccountToken=str(account_id),
        originalPurchaseDate=int(now.timestamp() * 1000),
        purchaseDate=int(now.timestamp() * 1000),
        expiresDate=int((now + timedelta(days=30)).timestamp() * 1000),
        revocationDate=None,
    )

    purchase = _apple_purchase(
        transaction,
        allowed_products=("com.convocoach.plus.monthly",),
        expected_account_reference=account_id,
        expected_product_id="com.convocoach.plus.monthly",
    )

    assert purchase.status == StorePurchaseStatus.ACTIVE
    assert purchase.account_reference == account_id


def test_google_projection_rejects_pending_and_accepts_bound_active_purchase() -> None:
    now = datetime.now(UTC)
    account_id = UUID("22222222-2222-4222-8222-222222222222")
    payload = {
        "startTime": now.isoformat(),
        "subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
        "externalAccountIdentifiers": {"obfuscatedExternalAccountId": str(account_id)},
        "lineItems": [
            {
                "productId": "com.convocoach.plus.yearly",
                "expiryTime": (now + timedelta(days=365)).isoformat(),
            }
        ],
    }

    purchase = _google_purchase(
        payload,
        purchase_token="opaque-purchase-token",
        allowed_products=("com.convocoach.plus.yearly",),
        expected_account_reference=account_id,
        expected_product_id="com.convocoach.plus.yearly",
    )

    assert purchase.status == StorePurchaseStatus.ACTIVE
    payload["subscriptionState"] = "SUBSCRIPTION_STATE_PENDING"
    with pytest.raises(ValueError):
        _google_purchase(
            payload,
            purchase_token="opaque-purchase-token",
            allowed_products=("com.convocoach.plus.yearly",),
            expected_account_reference=account_id,
            expected_product_id="com.convocoach.plus.yearly",
        )
