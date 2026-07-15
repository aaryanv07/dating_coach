"""Privacy deletion foundation routes."""

from fastapi import APIRouter, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.repositories.users import PrivacyRepository
from app.schemas.users import AccountDeletionRead

router = APIRouter(prefix="/api/v1/privacy", tags=["privacy"])


@router.post(
    "/delete-account",
    response_model=AccountDeletionRead,
    status_code=status.HTTP_202_ACCEPTED,
)
async def request_account_deletion(
    user: CurrentUser,
    session: DatabaseSession,
) -> AccountDeletionRead:
    """Remove private data and record pending external identity cleanup."""
    request = await PrivacyRepository(session).request_account_deletion(user)
    await session.commit()
    return AccountDeletionRead(
        request_id=request.id,
        status=request.status,
        requested_at=request.requested_at,
    )
