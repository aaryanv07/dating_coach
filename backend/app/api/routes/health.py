"""Service health endpoints."""

from typing import Annotated, Literal, cast

from fastapi import APIRouter, Depends, Request, Response, status
from pydantic import BaseModel

from app import __version__
from app.core.config import Settings
from app.core.lifecycle import (
    ApplicationLifecycleState,
    OperationalReadinessSnapshot,
)

router = APIRouter(prefix="/health", tags=["health"])


class LivenessResponse(BaseModel):
    """Liveness response contract."""

    status: Literal["ok"]
    service: str
    version: str


class DependencyChecks(BaseModel):
    """Content-free configuration and dependency states."""

    configuration: Literal["valid", "incomplete"]
    lifecycle: Literal["created", "starting", "ready", "stopping", "stopped"]
    database: Literal["ready", "not_ready", "not_checked", "missing"]
    migrations: Literal["compatible", "incompatible", "not_checked"]
    redis: Literal["ready", "not_ready", "not_checked", "missing"]


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
def readiness(
    request: Request,
    response: Response,
    settings: SettingsDependency,
) -> ReadinessResponse:
    """Report actual lifecycle/dependency state without performing side effects."""
    lifecycle = cast(
        ApplicationLifecycleState,
        request.app.state.lifecycle,
    )
    snapshot = cast(
        OperationalReadinessSnapshot,
        request.app.state.operational_readiness,
    )
    checks_required = settings.operational_checks_enabled or settings.app_environment in {
        "staging",
        "production",
    }
    is_ready = (
        lifecycle == ApplicationLifecycleState.READY
        and settings.dependencies_configured
        and (snapshot.ready if checks_required else True)
    )

    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return ReadinessResponse(
        status="ready" if is_ready else "not_ready",
        checks=DependencyChecks(
            configuration=("valid" if settings.dependencies_configured else "incomplete"),
            lifecycle=lifecycle.value,
            database=(snapshot.database.value if settings.database_url.strip() else "missing"),
            migrations=snapshot.migrations.value,
            redis=snapshot.redis.value if settings.redis_url.strip() else "missing",
        ),
    )
