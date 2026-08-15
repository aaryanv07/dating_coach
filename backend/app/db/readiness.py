"""Dependency connectivity and migration compatibility checks."""

import asyncio
import ssl
from contextlib import suppress
from urllib.parse import unquote, urlsplit

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncEngine

from app.core.lifecycle import (
    DatabaseReadinessStatus,
    MigrationCompatibilityStatus,
    OperationalReadinessSnapshot,
    RedisReadinessStatus,
)

EXPECTED_DATABASE_REVISION = "20260813_0008"


class InfrastructureOperationalReadinessChecker:
    """Check required dependencies and exact revision without modifying state."""

    def __init__(
        self,
        engine: AsyncEngine,
        *,
        redis_url: str,
        redis_ca_certificate_path: str = "",
        expected_revision: str = EXPECTED_DATABASE_REVISION,
        timeout_seconds: float = 3.0,
    ) -> None:
        self._engine = engine
        self._redis_url = redis_url
        self._redis_ca_certificate_path = redis_ca_certificate_path
        self._expected_revision = expected_revision
        self._timeout_seconds = timeout_seconds

    async def check(self) -> OperationalReadinessSnapshot:
        database, migrations = await self._check_database()
        redis = await self._check_redis()
        return OperationalReadinessSnapshot(
            database=database,
            migrations=migrations,
            redis=redis,
        )

    async def _check_database(
        self,
    ) -> tuple[DatabaseReadinessStatus, MigrationCompatibilityStatus]:
        try:
            async with asyncio.timeout(self._timeout_seconds):
                async with self._engine.connect() as connection:
                    await connection.execute(text("SELECT 1"))
                    result = await connection.execute(
                        text("SELECT version_num FROM alembic_version")
                    )
                    revision = result.scalar_one_or_none()
        except SQLAlchemyError:
            return (
                DatabaseReadinessStatus.NOT_READY,
                MigrationCompatibilityStatus.NOT_CHECKED,
            )
        except TimeoutError:
            return (
                DatabaseReadinessStatus.NOT_READY,
                MigrationCompatibilityStatus.NOT_CHECKED,
            )
        return (
            DatabaseReadinessStatus.READY,
            (
                MigrationCompatibilityStatus.COMPATIBLE
                if revision == self._expected_revision
                else MigrationCompatibilityStatus.INCOMPATIBLE
            ),
        )

    async def _check_redis(self) -> RedisReadinessStatus:
        parsed = urlsplit(self._redis_url)
        hostname = parsed.hostname
        if hostname is None:
            return RedisReadinessStatus.NOT_READY
        port = parsed.port or (6380 if parsed.scheme == "rediss" else 6379)
        writer: asyncio.StreamWriter | None = None
        try:
            ssl_context: ssl.SSLContext | bool | None = (
                ssl.create_default_context(
                    cafile=self._redis_ca_certificate_path or None,
                )
                if parsed.scheme == "rediss"
                else None
            )
            async with asyncio.timeout(self._timeout_seconds):
                reader, writer = await asyncio.open_connection(
                    hostname,
                    port,
                    ssl=ssl_context,
                    server_hostname=hostname if ssl_context else None,
                )
                if parsed.password is not None:
                    auth_parts = (
                        ("AUTH", unquote(parsed.username), unquote(parsed.password))
                        if parsed.username is not None
                        else ("AUTH", unquote(parsed.password))
                    )
                    await self._send_redis_command(writer, auth_parts)
                    if not (await reader.readline()).startswith(b"+OK"):
                        return RedisReadinessStatus.NOT_READY
                database_number = parsed.path.removeprefix("/")
                if database_number and database_number != "0":
                    await self._send_redis_command(
                        writer,
                        ("SELECT", database_number),
                    )
                    if not (await reader.readline()).startswith(b"+OK"):
                        return RedisReadinessStatus.NOT_READY
                await self._send_redis_command(writer, ("PING",))
                response = await reader.readline()
                return (
                    RedisReadinessStatus.READY
                    if response.startswith(b"+PONG")
                    else RedisReadinessStatus.NOT_READY
                )
        except (OSError, TimeoutError, ValueError, ssl.SSLError):
            return RedisReadinessStatus.NOT_READY
        finally:
            if writer is not None:
                writer.close()
                with suppress(OSError, ssl.SSLError):
                    await writer.wait_closed()

    @staticmethod
    async def _send_redis_command(
        writer: asyncio.StreamWriter,
        parts: tuple[str, ...],
    ) -> None:
        encoded_parts = tuple(part.encode("utf-8") for part in parts)
        payload = [f"*{len(encoded_parts)}\r\n".encode("ascii")]
        for part in encoded_parts:
            payload.extend(
                (
                    f"${len(part)}\r\n".encode("ascii"),
                    part,
                    b"\r\n",
                )
            )
        writer.writelines(payload)
        await writer.drain()
