"""Versioned owner-controlled privacy export contracts."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

from app.domain.conversation_events import JsonObject


class AccountExportV1(BaseModel):
    """One authenticated user's portable application data."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    schema_version: Literal["account-export.v1"] = "account-export.v1"
    generated_at: datetime
    data: JsonObject
