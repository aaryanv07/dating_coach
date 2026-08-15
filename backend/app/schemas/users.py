"""User, preference, profile, consent, and deletion API contracts."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

NonEmptyText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]
ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
ProfileItem = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=48)]
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
    age: int | None
    gender: str | None
    profile_setup_completed: bool
    relationship_intention: str | None
    communication_tone: str | None
    texting_style: str | None
    preferred_message_length: str | None
    uses_emojis: bool | None
    job_title: str | None
    likes: list[str]
    looking_for: list[str]
    has_profile_photo: bool
    profile_photo_updated_at: datetime | None
    updated_at: datetime


class CommunicationProfileUpdate(BaseModel):
    """Partial communication profile update."""

    preferred_name: ShortText | None = None
    age: Annotated[int, Field(ge=18, le=120)] | None = None
    gender: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)] | None
    ) = None
    profile_setup_completed: bool | None = None
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
    job_title: (
        Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
        | None
    ) = None
    likes: Annotated[list[ProfileItem], Field(max_length=12)] | None = None
    looking_for: Annotated[list[ProfileItem], Field(max_length=12)] | None = None

    @model_validator(mode="after")
    def completed_setup_has_required_fields(self) -> "CommunicationProfileUpdate":
        if self.profile_setup_completed is not True:
            return self
        if self.preferred_name is None:
            raise ValueError("preferred_name is required to complete profile setup")
        if self.age is None:
            raise ValueError("adult age is required to complete profile setup")
        if not self.likes:
            raise ValueError("at least one hobby or interest is required to complete profile setup")
        return self


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
