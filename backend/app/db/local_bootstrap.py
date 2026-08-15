"""Create a local-only SQLite development schema without pretending it is a migration."""

import asyncio

from app.core.config import get_settings
from app.db import models as database_models
from app.db.base import Base
from app.db.session import create_database_engine

del database_models


async def bootstrap() -> None:
    settings = get_settings()
    if settings.app_environment != "local" or not settings.database_url.startswith(
        "sqlite+aiosqlite:///"
    ):
        raise RuntimeError("local_sqlite_bootstrap_refused")
    engine = create_database_engine(settings.database_url)
    try:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
    finally:
        await engine.dispose()


def main() -> None:
    asyncio.run(bootstrap())


if __name__ == "__main__":
    main()
