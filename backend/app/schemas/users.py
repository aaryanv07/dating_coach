"""User, preference, profile, consent, and deletion API contracts."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

NonEmptyText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]
ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
Language = Literal["english", "mostly_english", "hinglish", "roman_hindi"]
CoachingStyle = Literal["gentle", "balanced", "direct"]


class UserRead(BaseModel):
    """Authenticated application user."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str | None
    display_name: str | None
    created_at: datetime


class UserPreferenceRead(BaseModel):
    """Stored application preferences."""

    model_config = ConfigDict(from_attributes=True)

    preferred_language: Language
    coaching_style: CoachingStyle
    save_history: bool
    updated_at: datetime


class UserPreferenceUpdate(BaseModel):
    """Partial user preference update."""

    preferred_language: Language | None = None
    coaching_style: CoachingStyle | None = None
    save_history: bool | None = None


class CommunicationProfileRead(BaseModel):
    """Explicit communication profile fields."""

    model_config = ConfigDict(from_attributes=True)

    preferred_name: str | None
    relationship_intention: str | None
    communication_tone: str | None
    texting_style: str | None
    preferred_message_length: str | None
    uses_emojis: bool | None
    updated_at: datetime


class CommunicationProfileUpdate(BaseModel):
    """Partial communication profile update."""

    preferred_name: ShortText | None = None
    relationship_intention: (
        Literal["serious", "exploring", "casual", "friendship_first", "unsure"] | None
    ) = None
    communication_tone: (
        Literal[
            "natural", "playful", "calm", "direct", "thoughtful", "romantic", "funny", "reserved"
        ]
        | None
    ) = None
    texting_style: Literal["concise", "balanced", "detailed"] | None = None
    preferred_message_length: Literal["short", "medium", "long"] | None = None
    uses_emojis: bool | None = None


class ConsentCreate(BaseModel):
    """One explicit consent decision."""

    consent_type: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)
    ]
    granted: bool
    policy_version: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=32)
    ]


class ConsentRead(BaseModel):
    """Persisted consent decision."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    consent_type: str
    granted: bool
    policy_version: str
    recorded_at: datetime


class AccountDeletionRead(BaseModel):
    """Account deletion foundation status."""

    request_id: UUID
    status: Literal["pending", "completed", "failed"]
    requested_at: datetime
    message: str = Field(
        default="Private account data was removed; provider-account cleanup is pending."
    )
