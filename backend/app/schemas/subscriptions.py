"""Owner-scoped, content-free subscription and allowance API contracts."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, StringConstraints

from app.subscriptions.contracts import AllowanceKind, SubscriptionPlanCode
from app.subscriptions.store_verification import Storefront

StoreEvidence = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=32768),
]
StoreProductId = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=128,
        pattern=r"^[A-Za-z0-9][A-Za-z0-9._-]*$",
    ),
]


class AllowanceStatusV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["allowance-status.v1"] = "allowance-status.v1"
    kind: AllowanceKind
    limit: int
    consumed: int
    reserved: int
    remaining: int
    reset_at: datetime


class SubscriptionStatusV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["subscription-status.v1"] = "subscription-status.v1"
    server_version: Literal["subscription-runtime.v1"] = "subscription-runtime.v1"
    plan_code: SubscriptionPlanCode
    plan_status: Literal["active", "grace"]
    purchase_enabled: bool = False
    allowances: tuple[AllowanceStatusV1, ...]
    generated_at: datetime


class StorePurchaseContextV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["store-purchase-context.v1"] = "store-purchase-context.v1"
    account_reference: UUID
    purchase_enabled: bool


class StorePurchaseVerificationRequestV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["store-purchase-verification-request.v1"] = (
        "store-purchase-verification-request.v1"
    )
    storefront: Storefront
    product_id: StoreProductId
    verification_data: StoreEvidence


class StorePurchaseVerificationResponseV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["store-purchase-verification-response.v1"] = (
        "store-purchase-verification-response.v1"
    )
    plan_code: Literal[SubscriptionPlanCode.PLUS] = SubscriptionPlanCode.PLUS
    plan_status: Literal["active", "grace", "expired", "revoked"]
    current_period_end: datetime


class AppleStoreNotificationV1(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    signedPayload: Annotated[str, StringConstraints(min_length=1, max_length=65536)]
