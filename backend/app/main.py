"""FastAPI application entry point."""

from fastapi import FastAPI

from app import __version__
from app.api.routes import health
from app.core.config import Settings, get_settings


def create_app(settings: Settings | None = None) -> FastAPI:
    """Create an isolated FastAPI application instance."""
    runtime_settings = settings or get_settings()
    application = FastAPI(
        title=runtime_settings.app_name,
        debug=runtime_settings.debug,
        version=__version__,
    )
    application.state.settings = runtime_settings
    application.include_router(health.router)

    @application.get("/", include_in_schema=False)
    def service_index() -> dict[str, str]:
        return {
            "service": runtime_settings.app_name,
            "version": __version__,
            "documentation": "/docs",
        }

    return application


app = create_app()
