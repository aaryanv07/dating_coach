"""Fail-closed Apple and Google subscription verification adapters."""

from __future__ import annotations

import asyncio
import json
from base64 import b64decode
from dataclasses import dataclass
from datetime import UTC, datetime
from enum import StrEnum
from typing import Protocol, cast
from uuid import UUID

import google.auth
import httpx
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.Status import Status
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
)
from google.auth import exceptions as google_auth_exceptions
from google.auth.credentials import Credentials
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token, service_account

from app.core.config import Settings
from app.subscriptions.apple_roots import apple_root_certificates

_GOOGLE_ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
_MAX_VERIFICATION_DATA_BYTES = 32 * 1024
_MAX_NOTIFICATION_BYTES = 64 * 1024


class Storefront(StrEnum):
    APPLE = "apple"
    GOOGLE = "google"


class StorePurchaseStatus(StrEnum):
    ACTIVE = "active"
    GRACE = "grace"
    EXPIRED = "expired"
    REVOKED = "revoked"


@dataclass(frozen=True, slots=True)
class VerifiedStorePurchase:
    storefront: Storefront
    transaction_reference: str
    product_id: str
    account_reference: UUID
    period_start: datetime
    period_end: datetime
    status: StorePurchaseStatus


@dataclass(frozen=True, slots=True)
class StoreNotification:
    purchase: VerifiedStorePurchase | None
    notification_reference: str


@dataclass(frozen=True, slots=True)
class StoreVerificationError(Exception):
    code: str
    retryable: bool = False


class StorePurchaseVerifier(Protocol):
    async def verify_purchase(
        self,
        *,
        storefront: Storefront,
        product_id: str,
        verification_data: str,
        expected_account_reference: UUID,
    ) -> VerifiedStorePurchase: ...

    async def verify_apple_notification(self, signed_payload: str) -> StoreNotification: ...

    async def verify_google_notification(
        self,
        *,
        authorization: str,
        envelope: dict[str, object],
    ) -> StoreNotification: ...


class UnavailableStorePurchaseVerifier:
    async def verify_purchase(
        self,
        *,
        storefront: Storefront,
        product_id: str,
        verification_data: str,
        expected_account_reference: UUID,
    ) -> VerifiedStorePurchase:
        del storefront, product_id, verification_data, expected_account_reference
        raise StoreVerificationError("store_billing_unavailable")

    async def verify_apple_notification(self, signed_payload: str) -> StoreNotification:
        del signed_payload
        raise StoreVerificationError("store_billing_unavailable")

    async def verify_google_notification(
        self,
        *,
        authorization: str,
        envelope: dict[str, object],
    ) -> StoreNotification:
        del authorization, envelope
        raise StoreVerificationError("store_billing_unavailable")


class ProductionStorePurchaseVerifier:
    """Verify store-signed evidence and never trust client entitlement claims."""

    def __init__(self, settings: Settings) -> None:
        if not settings.store_billing_enabled:
            raise StoreVerificationError("store_billing_unavailable")
        self._settings = settings
        environment = (
            Environment.PRODUCTION
            if settings.apple_iap_environment == "production"
            else Environment.SANDBOX
        )
        self._apple = SignedDataVerifier(
            apple_root_certificates(),
            True,
            environment,
            settings.apple_iap_bundle_id,
            settings.apple_iap_app_id if environment == Environment.PRODUCTION else None,
        )
        self._google_credentials = self._build_google_credentials(settings)

    @staticmethod
    def _build_google_credentials(settings: Settings) -> Credentials:
        try:
            if settings.google_play_use_application_default_credentials:
                credentials, _ = google.auth.default(scopes=[_GOOGLE_ANDROID_PUBLISHER_SCOPE])
                return credentials
            service_account_info = json.loads(settings.google_play_service_account_json)
            if not isinstance(service_account_info, dict):
                raise ValueError
            return cast(
                Credentials,
                service_account.Credentials.from_service_account_info(  # type: ignore[no-untyped-call]
                    service_account_info,
                    scopes=[_GOOGLE_ANDROID_PUBLISHER_SCOPE],
                ),
            )
        except (
            TypeError,
            ValueError,
            json.JSONDecodeError,
            google_auth_exceptions.GoogleAuthError,
        ) as error:
            raise StoreVerificationError("google_store_credentials_invalid") from error

    async def verify_purchase(
        self,
        *,
        storefront: Storefront,
        product_id: str,
        verification_data: str,
        expected_account_reference: UUID,
    ) -> VerifiedStorePurchase:
        _validate_evidence(verification_data, maximum=_MAX_VERIFICATION_DATA_BYTES)
        if storefront == Storefront.APPLE:
            return await self._verify_apple_transaction(
                verification_data,
                expected_account_reference=expected_account_reference,
                expected_product_id=product_id,
            )
        if storefront == Storefront.GOOGLE:
            return await self._verify_google_purchase(
                verification_data,
                expected_account_reference=expected_account_reference,
                expected_product_id=product_id,
            )
        raise StoreVerificationError("storefront_unsupported")

    async def verify_apple_notification(self, signed_payload: str) -> StoreNotification:
        _validate_evidence(signed_payload, maximum=_MAX_NOTIFICATION_BYTES)
        try:
            decoded = await asyncio.to_thread(
                self._apple.verify_and_decode_notification,
                signed_payload,
            )
            reference = decoded.notificationUUID
            data = decoded.data
            if reference is None or data is None:
                raise StoreVerificationError("apple_notification_invalid")
            if data.signedTransactionInfo is None:
                return StoreNotification(purchase=None, notification_reference=reference)
            transaction = await asyncio.to_thread(
                self._apple.verify_and_decode_signed_transaction,
                data.signedTransactionInfo,
            )
            renewal = None
            if data.signedRenewalInfo is not None:
                renewal = await asyncio.to_thread(
                    self._apple.verify_and_decode_renewal_info,
                    data.signedRenewalInfo,
                )
            purchase = _apple_purchase(
                transaction,
                allowed_products=self._settings.apple_iap_product_ids,
                expected_account_reference=None,
                store_status=data.status,
                grace_period_expires_date=(
                    renewal.gracePeriodExpiresDate if renewal is not None else None
                ),
            )
            return StoreNotification(purchase=purchase, notification_reference=reference)
        except StoreVerificationError:
            raise
        except VerificationException as error:
            raise StoreVerificationError("apple_notification_invalid") from error
        except Exception as error:
            raise StoreVerificationError(
                "apple_notification_unavailable", retryable=True
            ) from error

    async def verify_google_notification(
        self,
        *,
        authorization: str,
        envelope: dict[str, object],
    ) -> StoreNotification:
        token = _bearer_token(authorization)
        try:
            claims = await asyncio.to_thread(
                id_token.verify_oauth2_token,
                token,
                GoogleAuthRequest(),
                self._settings.google_play_pubsub_audience,
            )
        except (ValueError, google_auth_exceptions.GoogleAuthError) as error:
            raise StoreVerificationError("google_notification_authentication_failed") from error
        if (
            claims.get("iss") not in {"accounts.google.com", "https://accounts.google.com"}
            or claims.get("email") != self._settings.google_play_pubsub_service_account
            or claims.get("email_verified") is not True
        ):
            raise StoreVerificationError("google_notification_authentication_failed")
        message = envelope.get("message")
        if not isinstance(message, dict):
            raise StoreVerificationError("google_notification_invalid")
        reference = message.get("messageId")
        encoded_data = message.get("data")
        if not isinstance(reference, str) or not reference or not isinstance(encoded_data, str):
            raise StoreVerificationError("google_notification_invalid")
        try:
            raw_data = b64decode(encoded_data, validate=True)
            if not raw_data or len(raw_data) > _MAX_NOTIFICATION_BYTES:
                raise ValueError
            payload = json.loads(raw_data)
        except (ValueError, UnicodeError, json.JSONDecodeError) as error:
            raise StoreVerificationError("google_notification_invalid") from error
        if not isinstance(payload, dict):
            raise StoreVerificationError("google_notification_invalid")
        if payload.get("packageName") != self._settings.google_play_package_name:
            raise StoreVerificationError("google_notification_package_mismatch")
        notification = payload.get("subscriptionNotification")
        if notification is None:
            return StoreNotification(purchase=None, notification_reference=reference)
        if not isinstance(notification, dict):
            raise StoreVerificationError("google_notification_invalid")
        purchase_token = notification.get("purchaseToken")
        product_id = notification.get("subscriptionId")
        if not isinstance(purchase_token, str) or not isinstance(product_id, str):
            raise StoreVerificationError("google_notification_invalid")
        purchase = await self._verify_google_purchase(
            purchase_token,
            expected_account_reference=None,
            expected_product_id=product_id,
        )
        return StoreNotification(purchase=purchase, notification_reference=reference)

    async def _verify_apple_transaction(
        self,
        signed_transaction: str,
        *,
        expected_account_reference: UUID,
        expected_product_id: str,
    ) -> VerifiedStorePurchase:
        try:
            transaction = await asyncio.to_thread(
                self._apple.verify_and_decode_signed_transaction,
                signed_transaction,
            )
            return _apple_purchase(
                transaction,
                allowed_products=self._settings.apple_iap_product_ids,
                expected_account_reference=expected_account_reference,
                expected_product_id=expected_product_id,
            )
        except StoreVerificationError:
            raise
        except VerificationException as error:
            raise StoreVerificationError("apple_purchase_invalid") from error
        except Exception as error:
            raise StoreVerificationError("apple_store_unavailable", retryable=True) from error

    async def _verify_google_purchase(
        self,
        purchase_token: str,
        *,
        expected_account_reference: UUID | None,
        expected_product_id: str,
    ) -> VerifiedStorePurchase:
        _validate_evidence(purchase_token, maximum=_MAX_VERIFICATION_DATA_BYTES)
        if expected_product_id not in self._settings.google_play_product_ids:
            raise StoreVerificationError("google_product_invalid")
        access_token = await self._google_access_token()
        package_name = self._settings.google_play_package_name
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            f"{package_name}/purchases/subscriptionsv2/tokens/{purchase_token}"
        )
        timeout = self._settings.store_verification_timeout_seconds
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
        except httpx.HTTPError as error:
            raise StoreVerificationError("google_store_unavailable", retryable=True) from error
        if response.status_code != 200:
            code = (
                "google_purchase_invalid"
                if response.status_code < 500
                else "google_store_unavailable"
            )
            raise StoreVerificationError(code, retryable=response.status_code >= 500)
        try:
            payload = response.json()
            purchase = _google_purchase(
                payload,
                purchase_token=purchase_token,
                allowed_products=self._settings.google_play_product_ids,
                expected_account_reference=expected_account_reference,
                expected_product_id=expected_product_id,
            )
        except (TypeError, ValueError, KeyError) as error:
            raise StoreVerificationError("google_purchase_invalid") from error
        if (
            purchase.status in {StorePurchaseStatus.ACTIVE, StorePurchaseStatus.GRACE}
            and payload.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_PENDING"
        ):
            await self._acknowledge_google_purchase(
                product_id=expected_product_id,
                purchase_token=purchase_token,
                access_token=access_token,
            )
        return purchase

    async def _google_access_token(self) -> str:
        try:
            await asyncio.to_thread(self._google_credentials.refresh, GoogleAuthRequest())
        except google_auth_exceptions.GoogleAuthError as error:
            raise StoreVerificationError("google_store_unavailable", retryable=True) from error
        token = self._google_credentials.token
        if not isinstance(token, str) or not token:
            raise StoreVerificationError("google_store_unavailable", retryable=True)
        return token

    async def _acknowledge_google_purchase(
        self,
        *,
        product_id: str,
        purchase_token: str,
        access_token: str,
    ) -> None:
        package_name = self._settings.google_play_package_name
        url = (
            "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            f"{package_name}/purchases/subscriptions/{product_id}/tokens/"
            f"{purchase_token}:acknowledge"
        )
        try:
            async with httpx.AsyncClient(
                timeout=self._settings.store_verification_timeout_seconds
            ) as client:
                response = await client.post(
                    url,
                    headers={"Authorization": f"Bearer {access_token}"},
                    json={},
                )
        except httpx.HTTPError as error:
            raise StoreVerificationError("google_acknowledgement_failed", retryable=True) from error
        if response.status_code not in {200, 204}:
            raise StoreVerificationError("google_acknowledgement_failed", retryable=True)


def _apple_purchase(
    transaction: object,
    *,
    allowed_products: tuple[str, ...],
    expected_account_reference: UUID | None,
    expected_product_id: str | None = None,
    store_status: Status | None = None,
    grace_period_expires_date: int | None = None,
) -> VerifiedStorePurchase:
    product_id = getattr(transaction, "productId", None)
    reference = getattr(transaction, "originalTransactionId", None) or getattr(
        transaction, "transactionId", None
    )
    account_token = getattr(transaction, "appAccountToken", None)
    purchase_date = getattr(transaction, "originalPurchaseDate", None) or getattr(
        transaction, "purchaseDate", None
    )
    expires_date = getattr(transaction, "expiresDate", None)
    revocation_date = getattr(transaction, "revocationDate", None)
    if (
        not isinstance(product_id, str)
        or product_id not in allowed_products
        or (expected_product_id is not None and product_id != expected_product_id)
        or not isinstance(reference, str)
        or not reference
        or not isinstance(account_token, str)
        or not isinstance(purchase_date, int)
        or not isinstance(expires_date, int)
    ):
        raise StoreVerificationError("apple_purchase_invalid")
    try:
        account_reference = UUID(account_token)
    except ValueError as error:
        raise StoreVerificationError("apple_account_reference_invalid") from error
    if expected_account_reference is not None and account_reference != expected_account_reference:
        raise StoreVerificationError("apple_account_reference_mismatch")
    start = _milliseconds_datetime(purchase_date)
    end = _milliseconds_datetime(expires_date)
    now = datetime.now(UTC)
    if revocation_date is not None or store_status == Status.REVOKED:
        status = StorePurchaseStatus.REVOKED
    elif store_status == Status.BILLING_GRACE_PERIOD:
        if grace_period_expires_date is None:
            raise StoreVerificationError("apple_grace_period_invalid")
        end = _milliseconds_datetime(grace_period_expires_date)
        status = StorePurchaseStatus.GRACE if end > now else StorePurchaseStatus.EXPIRED
    elif end > now and store_status not in {Status.EXPIRED}:
        status = StorePurchaseStatus.ACTIVE
    else:
        status = StorePurchaseStatus.EXPIRED
    if end <= start:
        raise StoreVerificationError("apple_purchase_period_invalid")
    return VerifiedStorePurchase(
        storefront=Storefront.APPLE,
        transaction_reference=reference,
        product_id=product_id,
        account_reference=account_reference,
        period_start=start,
        period_end=end,
        status=status,
    )


def _google_purchase(
    payload: object,
    *,
    purchase_token: str,
    allowed_products: tuple[str, ...],
    expected_account_reference: UUID | None,
    expected_product_id: str,
) -> VerifiedStorePurchase:
    if not isinstance(payload, dict):
        raise ValueError("google_purchase_invalid")
    external = payload.get("externalAccountIdentifiers")
    if not isinstance(external, dict):
        raise ValueError("google_account_reference_missing")
    account_text = external.get("obfuscatedExternalAccountId")
    if not isinstance(account_text, str):
        raise ValueError("google_account_reference_missing")
    account_reference = UUID(account_text)
    if expected_account_reference is not None and account_reference != expected_account_reference:
        raise ValueError("google_account_reference_mismatch")
    start = _iso_datetime(cast(str, payload["startTime"]))
    line_items = payload.get("lineItems")
    if not isinstance(line_items, list) or not line_items:
        raise ValueError("google_line_items_missing")
    matching = [
        item
        for item in line_items
        if isinstance(item, dict) and item.get("productId") == expected_product_id
    ]
    if expected_product_id not in allowed_products or not matching:
        raise ValueError("google_product_mismatch")
    expirations = [
        _iso_datetime(cast(str, item["expiryTime"]))
        for item in matching
        if isinstance(item.get("expiryTime"), str)
    ]
    if not expirations:
        raise ValueError("google_expiration_missing")
    end = max(expirations)
    state = payload.get("subscriptionState")
    now = datetime.now(UTC)
    if state == "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" and end > now:
        status = StorePurchaseStatus.GRACE
    elif (
        state
        in {
            "SUBSCRIPTION_STATE_ACTIVE",
            "SUBSCRIPTION_STATE_CANCELED",
        }
        and end > now
    ):
        status = StorePurchaseStatus.ACTIVE
    elif (
        state
        in {
            "SUBSCRIPTION_STATE_EXPIRED",
            "SUBSCRIPTION_STATE_ON_HOLD",
            "SUBSCRIPTION_STATE_PAUSED",
        }
        or end <= now
    ):
        status = StorePurchaseStatus.EXPIRED
    else:
        raise ValueError("google_purchase_state_ungrantable")
    if end <= start:
        raise ValueError("google_purchase_period_invalid")
    return VerifiedStorePurchase(
        storefront=Storefront.GOOGLE,
        transaction_reference=purchase_token,
        product_id=expected_product_id,
        account_reference=account_reference,
        period_start=start,
        period_end=end,
        status=status,
    )


def _validate_evidence(value: str, *, maximum: int) -> None:
    if (
        not value
        or len(value.encode("utf-8")) > maximum
        or value != value.strip()
        or any(ord(character) < 32 for character in value)
    ):
        raise StoreVerificationError("store_evidence_invalid")


def _bearer_token(authorization: str) -> str:
    prefix = "Bearer "
    if not authorization.startswith(prefix):
        raise StoreVerificationError("google_notification_authentication_failed")
    token = authorization[len(prefix) :]
    _validate_evidence(token, maximum=8192)
    return token


def _milliseconds_datetime(value: int) -> datetime:
    try:
        return datetime.fromtimestamp(value / 1000, UTC)
    except (OverflowError, OSError, ValueError) as error:
        raise StoreVerificationError("store_timestamp_invalid") from error


def _iso_datetime(value: str) -> datetime:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("store_timestamp_invalid")
    return parsed.astimezone(UTC)


def build_store_purchase_verifier(settings: Settings) -> StorePurchaseVerifier:
    if not settings.store_billing_enabled:
        return UnavailableStorePurchaseVerifier()
    return ProductionStorePurchaseVerifier(settings)
