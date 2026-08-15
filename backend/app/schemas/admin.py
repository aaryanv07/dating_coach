"""Privacy-safe operator API contracts."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, NonNegativeInt


class UserMetricsV1(BaseModel):
    """Aggregate account and AI-usage counts without user identity or content."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["user-metrics.v1"] = "user-metrics.v1"
    generated_at: datetime
    total_registered_accounts: NonNegativeInt
    active_accounts: NonNegativeInt
    deleted_accounts: NonNegativeInt
    new_registered_accounts_7d: NonNegativeInt
    new_registered_accounts_30d: NonNegativeInt
    paid_active_accounts: NonNegativeInt
    free_active_accounts: NonNegativeInt
    ai_active_accounts_24h: NonNegativeInt
    ai_active_accounts_7d: NonNegativeInt
    ai_active_accounts_30d: NonNegativeInt
