"""Authenticated owner-bound Phase 11 Conversation Coach preview endpoint."""

from collections.abc import Mapping
from typing import Annotated, cast
from uuid import UUID

from fastapi import APIRouter, Header, Request, Response, status
from fastapi.responses import JSONResponse

from app.api.dependencies import CurrentUser, DatabaseSession
from app.core.config import Settings
from app.core.observability import resolve_correlation_id
from app.schemas.conversation_coach import (
    CoachLiveSuccessV2,
    CoachPreviewErrorCode,
    CoachPreviewErrorV1,
    CoachPreviewFailureV1,
    CoachPreviewSuccessV1,
)
from app.services.conversation_coach import (
    CoachPreviewServiceFailure,
    ConversationCoachPreviewService,
)

router = APIRouter(prefix="/api/v1/conversations", tags=["conversation-coach"])
COACH_PREVIEW_PATH_SUFFIX = "/coach-preview"
NO_STORE_HEADERS = {
    "Cache-Control": "no-store, max-age=0",
    "Pragma": "no-cache",
    "X-Content-Type-Options": "nosniff",
}


def coach_preview_correlation_id(
    request: Request,
) -> UUID:
    """Read the request-scoped opaque identifier established by middleware."""
    candidate = getattr(request.state, "correlation_id", None)
    if isinstance(candidate, UUID):
        return candidate
    return resolve_correlation_id(str(candidate) if candidate is not None else None)


def coach_preview_failure_response(
    *,
    code: CoachPreviewErrorCode,
    correlation_id: UUID,
    http_status: int,
    retryable: bool = False,
    headers: Mapping[str, str] | None = None,
) -> JSONResponse:
    """Build the sole public error shape for this endpoint."""
    retry_key = f"coaching.error.{code.value}.retry" if retryable else None
    failure = CoachPreviewFailureV1(
        error=CoachPreviewErrorV1(
            error_id=f"coach-preview:{code.value}",
            code=code,
            localization_key=f"coaching.error.{code.value}",
            retryable=retryable,
            retry_guidance_localization_key=retry_key,
            correlation_id=correlation_id,
        )
    )
    response_headers = {**NO_STORE_HEADERS, **(headers or {})}
    return JSONResponse(
        status_code=http_status,
        content=failure.model_dump(mode="json"),
        headers=response_headers,
    )


@router.post(
    "/{conversation_id}/coach-preview",
    response_model=CoachPreviewSuccessV1 | CoachLiveSuccessV2,
    responses={
        401: {"model": CoachPreviewFailureV1},
        403: {"model": CoachPreviewFailureV1},
        404: {"model": CoachPreviewFailureV1},
        409: {"model": CoachPreviewFailureV1},
        422: {"model": CoachPreviewFailureV1},
        429: {"model": CoachPreviewFailureV1},
        500: {"model": CoachPreviewFailureV1},
        502: {"model": CoachPreviewFailureV1},
        503: {"model": CoachPreviewFailureV1},
        504: {"model": CoachPreviewFailureV1},
    },
)
async def create_coach_preview(
    conversation_id: UUID,
    request: Request,
    response: Response,
    user: CurrentUser,
    session: DatabaseSession,
    idempotency_key: Annotated[
        str | None,
        Header(alias="Idempotency-Key", max_length=64),
    ] = None,
) -> CoachPreviewSuccessV1 | CoachLiveSuccessV2 | JSONResponse:
    """Execute one non-persistent mock preview or consented external-AI request."""
    correlation_id = coach_preview_correlation_id(request)
    if await request.body():
        return coach_preview_failure_response(
            code=CoachPreviewErrorCode.SCHEMA_UNSUPPORTED,
            correlation_id=correlation_id,
            http_status=status.HTTP_422_UNPROCESSABLE_CONTENT,
        )

    settings = cast(Settings, request.app.state.settings)
    if settings.ai_provider_mode in {"openai_terra", "zai_glm", "openrouter_tiered"}:
        try:
            parsed_idempotency_key = UUID(idempotency_key or "")
        except ValueError:
            return coach_preview_failure_response(
                code=CoachPreviewErrorCode.IDEMPOTENCY_REQUIRED,
                correlation_id=correlation_id,
                http_status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            )
        if str(parsed_idempotency_key) != idempotency_key:
            return coach_preview_failure_response(
                code=CoachPreviewErrorCode.IDEMPOTENCY_REQUIRED,
                correlation_id=correlation_id,
                http_status=status.HTTP_422_UNPROCESSABLE_CONTENT,
            )
    try:
        result = await ConversationCoachPreviewService(
            session,
            settings,
        ).execute(
            owner_id=user.id,
            conversation_id=conversation_id,
            correlation_id=correlation_id,
            idempotency_key=idempotency_key,
        )
    except CoachPreviewServiceFailure as failure:
        return coach_preview_failure_response(
            code=failure.code,
            correlation_id=correlation_id,
            http_status=failure.http_status,
            retryable=failure.retryable,
        )
    except Exception:
        return coach_preview_failure_response(
            code=CoachPreviewErrorCode.INTERNAL_SAFE_FAILURE,
            correlation_id=correlation_id,
            http_status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            retryable=True,
        )

    for name, value in NO_STORE_HEADERS.items():
        response.headers[name] = value
    response.headers["X-Correlation-ID"] = str(correlation_id)
    return result
