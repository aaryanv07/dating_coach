"""Immutable contracts for the default-off AI execution lifecycle."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from uuid import UUID

from app.ai.coaching_response_contracts import (
    CoachingResponseValidationFailureV1,
)
from app.ai.coaching_response_projection import CoachingRendererProjectionV1
from app.ai.contracts import (
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestRequirementsV1,
    AISafetyFailureV1,
)


class AIExecutionStage(StrEnum):
    RECEIVED = "received"
    VERSION_NEGOTIATION = "version_negotiation"
    ANALYTICS = "analytics"
    EVIDENCE = "evidence"
    SAFETY = "safety"
    REQUEST = "request"
    PROVIDER = "provider"
    PROVIDER_RESPONSE_PARSER = "provider_response_parser"
    STRUCTURED_RESPONSE = "structured_response"
    STRUCTURED_RESPONSE_PARSER = "structured_response_parser"
    RESPONSE_VALIDATION = "response_validation"
    RENDERER_PROJECTION = "renderer_projection"
    COMPLETED = "completed"


class AIExecutionDiagnosticStatus(StrEnum):
    PASSED = "passed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    TIMED_OUT = "timed_out"
    UNSUPPORTED = "unsupported"
    DISABLED = "disabled"


class AIExecutionState(StrEnum):
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    TIMED_OUT = "timed_out"
    UNSUPPORTED = "unsupported"
    DISABLED = "disabled"


class AIExecutionFailureCode(StrEnum):
    EXECUTION_DISABLED = "execution_disabled"
    MOCK_DISABLED = "mock_disabled"
    CANCELLED = "cancelled"
    TIMED_OUT = "timed_out"
    UNSUPPORTED_RESPONSE_VERSION = "unsupported_response_version"
    ANALYTICS_FAILURE = "analytics_failure"
    SAFETY_REJECTED = "safety_rejected"
    PROVIDER_UNAVAILABLE = "provider_unavailable"
    PROVIDER_FAILURE = "provider_failure"
    PROVIDER_RESPONSE_INVALID = "provider_response_invalid"
    STRUCTURED_RESPONSE_PARSE_FAILURE = "structured_response_parse_failure"
    RESPONSE_VALIDATION_FAILURE = "response_validation_failure"


class AIExecutionInterruption(StrEnum):
    CANCELLED = "cancelled"
    TIMED_OUT = "timed_out"


@dataclass(frozen=True, slots=True)
class AIExecutionRequestV1:
    request_id: UUID
    requirements: AIRequestRequirementsV1
    template: AIPromptTemplateV1
    intent: AIRequestIntentV1
    accepted_response_versions: tuple[str, ...]
    schema_version: Literal["ai-execution-request.v1"] = "ai-execution-request.v1"


@dataclass(frozen=True, slots=True)
class AIExecutionContextV1:
    execution_id: UUID
    evidence_package_id: UUID
    response_id: UUID
    schema_version: Literal["ai-execution-context.v1"] = "ai-execution-context.v1"


@dataclass(frozen=True, slots=True)
class AIExecutionDiagnosticV1:
    sequence: int
    stage: AIExecutionStage
    status: AIExecutionDiagnosticStatus
    schema_version: Literal["ai-execution-diagnostic.v1"] = "ai-execution-diagnostic.v1"


@dataclass(frozen=True, slots=True)
class AIExecutionCompletedV1:
    context: AIExecutionContextV1
    state: Literal[AIExecutionState.COMPLETED]
    projection: CoachingRendererProjectionV1
    diagnostics: tuple[AIExecutionDiagnosticV1, ...]
    schema_version: Literal["ai-execution-completed.v1"] = "ai-execution-completed.v1"


@dataclass(frozen=True, slots=True)
class AIExecutionFailureV1:
    context: AIExecutionContextV1
    state: AIExecutionState
    code: AIExecutionFailureCode
    diagnostics: tuple[AIExecutionDiagnosticV1, ...]
    safety_failures: tuple[AISafetyFailureV1, ...] = ()
    response_failures: tuple[CoachingResponseValidationFailureV1, ...] = ()
    schema_version: Literal["ai-execution-failure.v1"] = "ai-execution-failure.v1"


type AIExecutionResultV1 = AIExecutionCompletedV1 | AIExecutionFailureV1
