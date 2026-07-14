"""Environment-backed application settings."""

from dataclasses import dataclass
from functools import lru_cache
from os import getenv

DEFAULT_DATABASE_URL = (
    "postgresql+asyncpg://convocoach:convocoach_local_only@127.0.0.1:5432/convocoach"
)
DEFAULT_REDIS_URL = "redis://127.0.0.1:6379/0"


def _parse_bool(value: str) -> bool:
    """Parse a conventional environment boolean."""
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True, slots=True)
class Settings:
    """Runtime settings required by the Phase 1 API."""

    app_name: str = "ConvoCoach API"
    app_environment: str = "local"
    debug: bool = False
    database_url: str = DEFAULT_DATABASE_URL
    redis_url: str = DEFAULT_REDIS_URL

    @property
    def dependencies_configured(self) -> bool:
        """Whether required dependency locations are present, without probing them."""
        return bool(self.database_url.strip() and self.redis_url.strip())


@lru_cache
def get_settings() -> Settings:
    """Build and cache settings from the process environment."""
    return Settings(
        app_name=getenv("APP_NAME", "ConvoCoach API").strip(),
        app_environment=getenv("APP_ENVIRONMENT", "local").strip(),
        debug=_parse_bool(getenv("APP_DEBUG", "false")),
        database_url=getenv("DATABASE_URL", DEFAULT_DATABASE_URL).strip(),
        redis_url=getenv("REDIS_URL", DEFAULT_REDIS_URL).strip(),
    )
