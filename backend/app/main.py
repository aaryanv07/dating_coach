"""FastAPI application entry point."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy.ext.asyncio import AsyncEngine

from app import __version__
from app.api.routes import (
    authentication,
    communication_profile,
    consents,
    conversations,
    health,
    privacy,
    users,
)
from app.auth.verifier import AuthenticationVerifier, build_authentication_verifier
from app.core.config import Settings, get_settings
from app.db.session import (
    SessionFactory,
    create_database_engine,
    create_session_factory,
)


def create_app(
    settings: Settings | None = None,
    *,
    session_factory: SessionFactory | None = None,
    auth_verifier: AuthenticationVerifier | None = None,
) -> FastAPI:
    """Create an isolated FastAPI application instance."""
    runtime_settings = settings or get_settings()
    owned_engine: AsyncEngine | None = None
    if session_factory is None and runtime_settings.database_url:
        owned_engine = create_database_engine(runtime_settings.database_url)
        session_factory = create_session_factory(owned_engine)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        try:
            yield
        finally:
            if owned_engine is not None:
                await owned_engine.dispose()

    application = FastAPI(
        title=runtime_settings.app_name,
        debug=runtime_settings.debug,
        version=__version__,
        lifespan=lifespan,
    )
    application.state.settings = runtime_settings
    application.state.session_factory = session_factory
    application.state.auth_verifier = auth_verifier or build_authentication_verifier(
        runtime_settings
    )
    application.include_router(health.router)
    application.include_router(authentication.router)
    application.include_router(users.router)
    application.include_router(communication_profile.router)
    application.include_router(consents.router)
    application.include_router(conversations.router)
    application.include_router(privacy.router)

    @application.get("/", include_in_schema=False)
    def service_index() -> dict[str, str]:
        return {
            "service": runtime_settings.app_name,
            "version": __version__,
            "documentation": "/docs",
        }

    return application


app = create_app()
