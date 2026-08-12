"""FastAPI application entry point."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exception_handlers import (
    http_exception_handler,
    request_validation_exception_handler,
)
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response
from sqlalchemy.ext.asyncio import AsyncEngine
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app import __version__
from app.api.routes import (
    admin,
    authentication,
    communication_profile,
    consents,
    conversation_coach,
    conversations,
    health,
    privacy,
    subscriptions,
    users,
)
from app.auth.verifier import AuthenticationVerifier, build_authentication_verifier
from app.core.config import Settings, get_settings, validate_settings
from app.core.lifecycle import (
    ApplicationLifecycleState,
    OperationalReadinessChecker,
    OperationalReadinessSnapshot,
    OperationalStartupError,
)
from app.core.observability import configure_operational_logging
from app.core.operational_middleware import (
    OperationalMiddleware,
    RequestBodyLimitMiddleware,
)
from app.db.readiness import InfrastructureOperationalReadinessChecker
from app.db.session import (
    SessionFactory,
    create_database_engine,
    create_session_factory,
)
from app.schemas.conversation_coach import CoachPreviewErrorCode
from app.subscriptions.store_verification import (
    StorePurchaseVerifier,
    build_store_purchase_verifier,
)


def create_app(
    settings: Settings | None = None,
    *,
    session_factory: SessionFactory | None = None,
    auth_verifier: AuthenticationVerifier | None = None,
    store_purchase_verifier: StorePurchaseVerifier | None = None,
    readiness_checker: OperationalReadinessChecker | None = None,
) -> FastAPI:
    """Create an isolated FastAPI application instance."""
    runtime_settings = settings or get_settings()
    validate_settings(runtime_settings)
    operational_logger = configure_operational_logging(runtime_settings.log_level)
    owned_engine: AsyncEngine | None = None
    if session_factory is None and runtime_settings.database_url:
        owned_engine = create_database_engine(runtime_settings.database_url)
        session_factory = create_session_factory(owned_engine)
    if readiness_checker is None and owned_engine is not None:
        readiness_checker = InfrastructureOperationalReadinessChecker(
            owned_engine,
            redis_url=runtime_settings.redis_url,
            redis_ca_certificate_path=runtime_settings.redis_ca_certificate_path,
        )

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        application.state.lifecycle = ApplicationLifecycleState.STARTING
        operational_logger.info(
            "",
            extra={"event": "lifecycle_changed", "lifecycle": "starting"},
        )
        try:
            if runtime_settings.operational_checks_enabled:
                if readiness_checker is None:
                    raise OperationalStartupError("Operational readiness checker is unavailable.")
                snapshot = await readiness_checker.check()
                application.state.operational_readiness = snapshot
                if not snapshot.ready:
                    raise OperationalStartupError("Operational dependency checks failed.")
            application.state.lifecycle = ApplicationLifecycleState.READY
            operational_logger.info(
                "",
                extra={"event": "lifecycle_changed", "lifecycle": "ready"},
            )
            yield
        finally:
            application.state.lifecycle = ApplicationLifecycleState.STOPPING
            operational_logger.info(
                "",
                extra={"event": "lifecycle_changed", "lifecycle": "stopping"},
            )
            if owned_engine is not None:
                await owned_engine.dispose()
            application.state.lifecycle = ApplicationLifecycleState.STOPPED
            operational_logger.info(
                "",
                extra={"event": "lifecycle_changed", "lifecycle": "stopped"},
            )

    application = FastAPI(
        title=runtime_settings.app_name,
        debug=runtime_settings.debug,
        version=__version__,
        lifespan=lifespan,
        openapi_url="/openapi.json" if runtime_settings.openapi_enabled else None,
        docs_url="/docs" if runtime_settings.openapi_enabled else None,
        redoc_url=None,
    )
    application.state.settings = runtime_settings
    application.state.session_factory = session_factory
    application.state.lifecycle = ApplicationLifecycleState.CREATED
    application.state.operational_readiness = OperationalReadinessSnapshot.not_checked()
    application.state.auth_verifier = auth_verifier or build_authentication_verifier(
        runtime_settings
    )
    application.state.store_purchase_verifier = (
        store_purchase_verifier or build_store_purchase_verifier(runtime_settings)
    )
    application.include_router(health.router)
    application.include_router(admin.router)
    application.include_router(authentication.router)
    application.include_router(users.router)
    application.include_router(communication_profile.router)
    application.include_router(consents.router)
    application.include_router(conversations.router)
    application.include_router(conversation_coach.router)
    application.include_router(subscriptions.router)
    application.include_router(privacy.router)
    application.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=list(runtime_settings.allowed_hosts),
    )
    application.add_middleware(
        RequestBodyLimitMiddleware,
        maximum_bytes=runtime_settings.max_request_body_bytes,
    )
    application.add_middleware(
        OperationalMiddleware,
        logger=operational_logger,
        production=runtime_settings.app_environment == "production",
    )

    @application.exception_handler(HTTPException)
    async def content_safe_coach_preview_error(
        request: Request,
        error: HTTPException,
    ) -> Response:
        if request.url.path.endswith(conversation_coach.COACH_REPORT_PATH_SUFFIX):
            detail = {
                status.HTTP_401_UNAUTHORIZED: "Authentication required",
                status.HTTP_403_FORBIDDEN: "Report unavailable",
                status.HTTP_404_NOT_FOUND: "Conversation not found",
            }.get(error.status_code, "Report unavailable")
            return JSONResponse(
                status_code=error.status_code,
                content={"detail": detail},
                headers={
                    **conversation_coach.NO_STORE_HEADERS,
                    **(error.headers or {}),
                },
            )
        if not request.url.path.endswith(conversation_coach.COACH_PREVIEW_PATH_SUFFIX):
            return await http_exception_handler(request, error)
        if error.status_code == status.HTTP_401_UNAUTHORIZED:
            code = CoachPreviewErrorCode.AUTHENTICATION_REQUIRED
        elif error.status_code == status.HTTP_403_FORBIDDEN:
            code = CoachPreviewErrorCode.AUTHORIZATION_FAILED
        elif error.status_code == status.HTTP_422_UNPROCESSABLE_CONTENT:
            code = CoachPreviewErrorCode.SCHEMA_UNSUPPORTED
        else:
            code = CoachPreviewErrorCode.INTERNAL_SAFE_FAILURE
        return conversation_coach.coach_preview_failure_response(
            code=code,
            correlation_id=conversation_coach.coach_preview_correlation_id(request),
            http_status=error.status_code,
            retryable=error.status_code >= 500,
            headers=error.headers,
        )

    @application.exception_handler(RequestValidationError)
    async def content_safe_coach_preview_validation_error(
        request: Request,
        error: RequestValidationError,
    ) -> Response:
        if request.url.path.endswith(conversation_coach.COACH_REPORT_PATH_SUFFIX):
            return JSONResponse(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                content={"detail": "Invalid report"},
                headers=conversation_coach.NO_STORE_HEADERS,
            )
        if not request.url.path.endswith(conversation_coach.COACH_PREVIEW_PATH_SUFFIX):
            return await request_validation_exception_handler(request, error)
        return conversation_coach.coach_preview_failure_response(
            code=CoachPreviewErrorCode.SCHEMA_UNSUPPORTED,
            correlation_id=conversation_coach.coach_preview_correlation_id(request),
            http_status=status.HTTP_422_UNPROCESSABLE_CONTENT,
        )

    @application.exception_handler(Exception)
    async def content_safe_unhandled_error(
        request: Request,
        _: Exception,
    ) -> JSONResponse:
        correlation_id = conversation_coach.coach_preview_correlation_id(request)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "error": {
                    "code": "internal_server_error",
                    "correlation_id": str(correlation_id),
                }
            },
        )

    @application.get("/", include_in_schema=False)
    def service_index() -> dict[str, str]:
        return {
            "service": runtime_settings.app_name,
            "version": __version__,
            "documentation": "/docs" if runtime_settings.openapi_enabled else "disabled",
        }

    return application


app = create_app()
