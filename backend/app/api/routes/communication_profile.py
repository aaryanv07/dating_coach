"""Authenticated communication-profile routes."""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import CommunicationProfile
from app.repositories.users import UserRepository
from app.schemas.users import CommunicationProfileRead, CommunicationProfileUpdate

router = APIRouter(prefix="/api/v1/communication-profile", tags=["communication-profile"])


@router.get("", response_model=CommunicationProfileRead)
async def read_communication_profile(
    user: CurrentUser, session: DatabaseSession
) -> CommunicationProfile:
    """Return explicit profile choices without inferred personality data."""
    profile = await UserRepository(session).get_profile(user.id)
    await session.commit()
    return profile


@router.patch("", response_model=CommunicationProfileRead)
async def update_communication_profile(
    payload: CommunicationProfileUpdate,
    user: CurrentUser,
    session: DatabaseSession,
) -> CommunicationProfile:
    """Persist a partial communication profile update."""
    profile = await UserRepository(session).update_profile(
        user.id,
        preferred_name=payload.preferred_name,
        relationship_intention=payload.relationship_intention,
        communication_tone=payload.communication_tone,
        texting_style=payload.texting_style,
        preferred_message_length=payload.preferred_message_length,
        uses_emojis=payload.uses_emojis,
    )
    await session.commit()
    return profile
