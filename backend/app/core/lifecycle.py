"""Content-free application lifecycle and operational-readiness contracts."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol


class ApplicationLifecycleState(StrEnum):
    CREATED = "created"
    STARTING = "starting"
    READY = "ready"
    STOPPING = "stopping"
    STOPPED = "stopped"


class DatabaseReadinessStatus(StrEnum):
    READY = "ready"
    NOT_READY = "not_ready"
    NOT_CHECKED = "not_checked"


class MigrationCompatibilityStatus(StrEnum):
    COMPATIBLE = "compatible"
    INCOMPATIBLE = "incompatible"
    NOT_CHECKED = "not_checked"


class RedisReadinessStatus(StrEnum):
    READY = "ready"
    NOT_READY = "not_ready"
    NOT_CHECKED = "not_checked"


@dataclass(frozen=True, slots=True)
class OperationalReadinessSnapshot:
    """Safe aggregate state without connection or migration details."""

    database: DatabaseReadinessStatus
    migrations: MigrationCompatibilityStatus
    redis: RedisReadinessStatus

    @property
    def ready(self) -> bool:
        return (
            self.database == DatabaseReadinessStatus.READY
            and self.migrations == MigrationCompatibilityStatus.COMPATIBLE
            and self.redis == RedisReadinessStatus.READY
        )

    @classmethod
    def not_checked(cls) -> "OperationalReadinessSnapshot":
        return cls(
            database=DatabaseReadinessStatus.NOT_CHECKED,
            migrations=MigrationCompatibilityStatus.NOT_CHECKED,
            redis=RedisReadinessStatus.NOT_CHECKED,
        )


class OperationalReadinessChecker(Protocol):
    """Perform bounded dependency checks without applying migrations."""

    async def check(self) -> OperationalReadinessSnapshot: ...


class OperationalStartupError(RuntimeError):
    """Content-free startup rejection for failed operational checks."""
