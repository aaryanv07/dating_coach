"""Authentication-session verification route."""

from fastapi import APIRouter

from app.api.dependencies import CurrentUser
from app.db.models import User
from app.schemas.users import UserRead

router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])


@router.post("/session/verify", response_model=UserRead)
async def verify_session(user: CurrentUser) -> User:
    """Verify the bearer token and return its server-owned user."""
    return user
