"""Injectable deterministic cancellation and timeout checkpoints."""

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol

from app.ai.contracts import AIRawProviderResponseV1
from app.ai.execution_contracts import AIExecutionInterruption, AIExecutionStage


class AIExecutionControl(Protocol):
    """Return an interruption before a stage, without exposing clocks or content."""

    def interruption_before(
        self,
        stage: AIExecutionStage,
    ) -> AIExecutionInterruption | None: ...


class AIExecutionCancelled(Exception):
    """Content-free signal from an injected asynchronous execution controller."""


class AIExecutionTimedOut(Exception):
    """Content-free signal from an injected asynchronous execution controller."""


class AIExecutionAwaiter(Protocol):
    """Wrap the provider await without constructing it before the controller runs."""

    async def run_provider(
        self,
        operation: Callable[[], Awaitable[AIRawProviderResponseV1]],
    ) -> AIRawProviderResponseV1: ...


class DirectAIExecutionAwaiter:
    """Default deterministic pass-through; performs no clock-based behavior."""

    async def run_provider(
        self,
        operation: Callable[[], Awaitable[AIRawProviderResponseV1]],
    ) -> AIRawProviderResponseV1:
        return await operation()


@dataclass(frozen=True, slots=True)
class StaticAIExecutionControl:
    """Deterministic test/default control with optional stage interruption."""

    cancel_before: AIExecutionStage | None = None
    timeout_before: AIExecutionStage | None = None

    def interruption_before(
        self,
        stage: AIExecutionStage,
    ) -> AIExecutionInterruption | None:
        if self.cancel_before == stage:
            return AIExecutionInterruption.CANCELLED
        if self.timeout_before == stage:
            return AIExecutionInterruption.TIMED_OUT
        return None
