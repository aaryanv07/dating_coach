"""Service health endpoints."""

from typing import Annotated, Literal, cast

from fastapi import APIRouter, Depends, Request, Response, status
from pydantic import BaseModel

from app import __version__
from app.core.config import Settings

router = APIRouter(prefix="/health", tags=["health"])


class LivenessResponse(BaseModel):
    """Liveness response contract."""

    status: Literal["ok"]
    service: str
    version: str


class DependencyChecks(BaseModel):
    """Configuration-level dependency checks."""

    database: Literal["configured", "missing"]
    redis: Literal["configured", "missing"]


class ReadinessResponse(BaseModel):
    """Readiness response contract."""

    status: Literal["ready", "not_ready"]
    checks: DependencyChecks


def _get_app_settings(request: Request) -> Settings:
    return cast(Settings, request.app.state.settings)


SettingsDependency = Annotated[Settings, Depends(_get_app_settings)]


@router.get("/live", response_model=LivenessResponse)
def liveness(settings: SettingsDependency) -> LivenessResponse:
    """Report that the API process can handle requests."""
    return LivenessResponse(status="ok", service=settings.app_name, version=__version__)


@router.get(
    "/ready",
    response_model=ReadinessResponse,
    responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"model": ReadinessResponse}},
)
def readiness(response: Response, settings: SettingsDependency) -> ReadinessResponse:
    """Fail closed when required dependency locations are not configured."""
    database_status: Literal["configured", "missing"] = (
        "configured" if settings.database_url.strip() else "missing"
    )
    redis_status: Literal["configured", "missing"] = (
        "configured" if settings.redis_url.strip() else "missing"
    )
    is_ready = settings.dependencies_configured

    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return ReadinessResponse(
        status="ready" if is_ready else "not_ready",
        checks=DependencyChecks(database=database_status, redis=redis_status),
    )
