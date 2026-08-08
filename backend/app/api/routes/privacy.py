"""Authenticated privacy export and deletion routes."""

from fastapi import APIRouter, Response, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import utc_now
from app.repositories.privacy_export import PrivacyExportRepository
from app.repositories.users import PrivacyRepository
from app.schemas.privacy import AccountExportV1
from app.schemas.users import AccountDeletionRead

router = APIRouter(prefix="/api/v1/privacy", tags=["privacy"])


@router.get("/export", response_model=AccountExportV1)
async def export_account_data(
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
) -> AccountExportV1:
    """Return one portable, owner-scoped export without raw source bytes."""
    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Content-Disposition"] = (
        'attachment; filename="convocoach-account-export.json"'
    )
    return AccountExportV1(
        generated_at=utc_now(),
        data=await PrivacyExportRepository(session).export(user),
    )


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
