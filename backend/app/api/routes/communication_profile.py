"""Authenticated communication-profile routes."""

from fastapi import APIRouter, HTTPException, Request, Response, status

from app.api.dependencies import CurrentUser, DatabaseSession
from app.db.models import CommunicationProfile
from app.repositories.users import UserRepository
from app.schemas.users import CommunicationProfileRead, CommunicationProfileUpdate

router = APIRouter(prefix="/api/v1/communication-profile", tags=["communication-profile"])

_PROFILE_PHOTO_TYPES = frozenset({"image/jpeg", "image/png", "image/webp"})
_MAX_PROFILE_PHOTO_BYTES = 900 * 1024
_PRIVATE_IMAGE_HEADERS = {"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"}


def _has_expected_image_signature(content: bytes, content_type: str) -> bool:
    signatures = {
        "image/jpeg": content.startswith(b"\xff\xd8\xff"),
        "image/png": content.startswith(b"\x89PNG\r\n\x1a\n"),
        "image/webp": len(content) >= 12
        and content.startswith(b"RIFF")
        and content[8:12] == b"WEBP",
    }
    return signatures.get(content_type, False)


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
        age=payload.age,
        gender=payload.gender,
        profile_setup_completed=payload.profile_setup_completed,
        relationship_intention=payload.relationship_intention,
        communication_tone=payload.communication_tone,
        texting_style=payload.texting_style,
        preferred_message_length=payload.preferred_message_length,
        uses_emojis=payload.uses_emojis,
        job_title=payload.job_title,
        likes=payload.likes,
        looking_for=payload.looking_for,
    )
    await session.commit()
    return profile


@router.get("/photo")
async def read_profile_photo(user: CurrentUser, session: DatabaseSession) -> Response:
    """Return only the authenticated owner's private profile photo."""
    profile = await UserRepository(session).get_profile(user.id)
    if profile.profile_photo_bytes is None or profile.profile_photo_content_type is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Photo unavailable")
    return Response(
        content=profile.profile_photo_bytes,
        media_type=profile.profile_photo_content_type,
        headers=_PRIVATE_IMAGE_HEADERS,
    )


@router.put("/photo", status_code=status.HTTP_204_NO_CONTENT)
async def update_profile_photo(
    request: Request,
    user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    """Store a bounded image in the encrypted owner-scoped database record."""
    content_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if content_type not in _PROFILE_PHOTO_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported profile photo",
        )
    declared_length = request.headers.get("content-length")
    if declared_length is not None:
        try:
            if int(declared_length) > _MAX_PROFILE_PHOTO_BYTES:
                raise HTTPException(
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    detail="Profile photo is too large",
                )
        except ValueError as error:
            raise HTTPException(status_code=400, detail="Invalid content length") from error
    content = await request.body()
    if not content or len(content) > _MAX_PROFILE_PHOTO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Profile photo is empty or too large",
        )
    if not _has_expected_image_signature(content, content_type):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Profile photo content is invalid",
        )
    await UserRepository(session).update_profile_photo(
        user.id,
        content=content,
        content_type=content_type,
    )
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT, headers=_PRIVATE_IMAGE_HEADERS)


@router.delete("/photo", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile_photo(user: CurrentUser, session: DatabaseSession) -> Response:
    """Remove the authenticated owner's profile photo immediately."""
    await UserRepository(session).update_profile_photo(user.id, content=None, content_type=None)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT, headers=_PRIVATE_IMAGE_HEADERS)
