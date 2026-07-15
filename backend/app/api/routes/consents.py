"""Append-only consent routes."""

from fastapi import APIRouter, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import ConsentRecord
from app.repositories.users import ConsentRepository
from app.schemas.users import ConsentCreate, ConsentRead

router = APIRouter(prefix="/api/v1/consents", tags=["consents"])


@router.post("", response_model=ConsentRead, status_code=status.HTTP_201_CREATED)
async def record_consent(
    payload: ConsentCreate,
    user: CurrentUser,
    session: DatabaseSession,
) -> ConsentRecord:
    """Append one explicit consent grant or withdrawal."""
    record = await ConsentRepository(session).record(
        user.id,
        consent_type=payload.consent_type,
        granted=payload.granted,
        policy_version=payload.policy_version,
    )
    await session.commit()
    return record


@router.get("", response_model=list[ConsentRead])
async def list_consents(user: CurrentUser, session: DatabaseSession) -> list[ConsentRecord]:
    """List only the authenticated user's consent history."""
    return await ConsentRepository(session).list_for_user(user.id)
