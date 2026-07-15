"""Authenticated user and preference routes."""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import User, UserPreference
from app.repositories.users import UserRepository
from app.schemas.users import UserPreferenceRead, UserPreferenceUpdate, UserRead

router = APIRouter(prefix="/api/v1/users", tags=["users"])


@router.get("/me", response_model=UserRead)
async def read_current_user(user: CurrentUser) -> User:
    """Return the current server-resolved user."""
    return user


@router.get("/me/preferences", response_model=UserPreferenceRead)
async def read_preferences(user: CurrentUser, session: DatabaseSession) -> UserPreference:
    """Return preferences, creating privacy-safe defaults when absent."""
    preferences = await UserRepository(session).get_preferences(user.id)
    await session.commit()
    return preferences


@router.patch("/me/preferences", response_model=UserPreferenceRead)
async def update_preferences(
    payload: UserPreferenceUpdate,
    user: CurrentUser,
    session: DatabaseSession,
) -> UserPreference:
    """Update only explicitly supplied preferences."""
    preferences = await UserRepository(session).update_preferences(
        user.id,
        preferred_language=payload.preferred_language,
        coaching_style=payload.coaching_style,
        save_history=payload.save_history,
    )
    await session.commit()
    return preferences
