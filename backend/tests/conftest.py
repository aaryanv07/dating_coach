"""Shared backend test fixtures."""

import asyncio
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine

from app.auth.verifier import AuthClaims, StaticAuthenticationVerifier
from app.core.config import Settings
from app.db.base import Base
from app.db.session import create_database_engine, create_session_factory
from app.main import create_app


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(create_app()) as test_client:
        yield test_client


async def _create_schema(engine: AsyncEngine) -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


@pytest.fixture
def api_client(tmp_path: Path) -> Iterator[TestClient]:
    """API client backed by an isolated relational database and two identities."""
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase3.db'}"
    engine = create_database_engine(database_url)

    @event.listens_for(engine.sync_engine, "connect")
    def enable_foreign_keys(dbapi_connection: Any, _: Any) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    asyncio.run(_create_schema(engine))
    verifier = StaticAuthenticationVerifier(
        {
            "token-a": AuthClaims(subject="subject-a", email="a@example.invalid"),
            "token-b": AuthClaims(subject="subject-b", email="b@example.invalid"),
        }
    )
    application = create_app(
        Settings(app_environment="test", database_url=database_url),
        session_factory=create_session_factory(engine),
        auth_verifier=verifier,
    )
    with TestClient(application) as test_client:
        yield test_client
    asyncio.run(engine.dispose())


@pytest.fixture
def auth_a() -> dict[str, str]:
    return {"Authorization": "Bearer token-a"}


@pytest.fixture
def auth_b() -> dict[str, str]:
    return {"Authorization": "Bearer token-b"}
