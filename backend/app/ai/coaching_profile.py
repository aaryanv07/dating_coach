"""Explicit, bounded user profile context for reply tailoring."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from app.db.models import CommunicationProfile


class UserCoachingProfileV1(BaseModel):
    """User-authored context; never inferred from a conversation or photo."""

    model_config = ConfigDict(extra="forbid", frozen=True, str_strip_whitespace=True)

    preferred_name: Annotated[str, Field(max_length=80)] = ""
    age: Annotated[int, Field(ge=18, le=120)] | None = None
    gender: Annotated[str, Field(max_length=64)] = ""
    job_title: Annotated[str, Field(max_length=100)] = ""
    likes: Annotated[tuple[Annotated[str, Field(max_length=48)], ...], Field(max_length=12)] = ()
    looking_for: Annotated[
        tuple[Annotated[str, Field(max_length=48)], ...], Field(max_length=12)
    ] = ()
    relationship_intention: Annotated[str, Field(max_length=32)] = ""
    communication_tone: Annotated[str, Field(max_length=32)] = ""
    preferred_message_length: Annotated[str, Field(max_length=16)] = ""
    uses_emojis: bool | None = None


def build_user_coaching_profile(
    profile: CommunicationProfile | None,
) -> UserCoachingProfileV1 | None:
    """Project only explicit text preferences; image bytes never reach AI."""
    if profile is None:
        return None
    context = UserCoachingProfileV1(
        preferred_name=profile.preferred_name or "",
        age=profile.age,
        gender=profile.gender or "",
        job_title=profile.job_title or "",
        likes=tuple(profile.likes),
        looking_for=tuple(profile.looking_for),
        relationship_intention=profile.relationship_intention or "",
        communication_tone=profile.communication_tone or "",
        preferred_message_length=profile.preferred_message_length or "",
        uses_emojis=profile.uses_emojis,
    )
    if not any(
        (
            context.preferred_name,
            context.age is not None,
            context.gender,
            context.job_title,
            context.likes,
            context.looking_for,
            context.relationship_intention,
            context.communication_tone,
            context.preferred_message_length,
            context.uses_emojis is not None,
        )
    ):
        return None
    return context
