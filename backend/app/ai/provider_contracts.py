"""Immutable contracts for the Phase 12 provider abstraction foundation."""

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Literal

from app.ai.coaching_response_contracts import CoachingCapability


class AIProviderClassification(StrEnum):
    """Whether metadata describes the local mock or a future production provider."""

    MOCK = "mock"
    PRODUCTION = "production"


class AIProviderLifecycleState(StrEnum):
    """Closed lifecycle state; Phase 12 permits only the mock to be active."""

    ACTIVE = "active"
    INACTIVE = "inactive"


class AIProviderVisibility(StrEnum):
    """Internal discovery visibility, never a customer-facing setting."""

    INTERNAL = "internal"
    HIDDEN = "hidden"


class AIProviderExecutionCapability(StrEnum):
    """Execution behavior currently supported by the provider boundary."""

    FOUNDATION_PLACEHOLDER = "foundation_placeholder"


class AIProviderFeatureFlag(StrEnum):
    """Existing fail-closed flags that may authorize structural availability."""

    AI_COACHING_ENABLED = "ai_coaching_enabled"
    AI_MOCK_EXECUTION_ENABLED = "ai_mock_execution_enabled"


class AIProviderHealthStatus(StrEnum):
    """Structural availability only; no network or provider probe is performed."""

    AVAILABLE = "available"
    DISABLED = "disabled"
    INACTIVE = "inactive"
    UNAVAILABLE = "unavailable"


class AIProviderCompatibilityFailureCode(StrEnum):
    """Stable, content-free provider compatibility rejection reasons."""

    PROVIDER_UNSUPPORTED = "provider_unsupported"
    PROVIDER_INACTIVE = "provider_inactive"
    PROVIDER_NOT_MOCK = "provider_not_mock"
    REQUEST_SCHEMA_UNSUPPORTED = "request_schema_unsupported"
    RESPONSE_SCHEMA_UNSUPPORTED = "response_schema_unsupported"
    EXECUTION_CAPABILITY_UNSUPPORTED = "execution_capability_unsupported"
    RESPONSE_CAPABILITY_UNSUPPORTED = "response_capability_unsupported"
    LANGUAGE_UNSUPPORTED = "language_unsupported"
    FEATURE_FLAG_DISABLED = "feature_flag_disabled"
    PROVIDER_UNAVAILABLE = "provider_unavailable"


@dataclass(frozen=True, slots=True)
class AIProviderMetadataV1:
    """Immutable provider discovery metadata with no secrets or endpoints."""

    identifier: str
    version: str
    family: str
    supported_request_schema_versions: tuple[str, ...]
    supported_response_schema_versions: tuple[str, ...]
    execution_capabilities: tuple[AIProviderExecutionCapability, ...]
    response_capabilities: tuple[CoachingCapability, ...]
    languages: tuple[str, ...]
    maximum_request_schema_version: str
    maximum_response_schema_version: str
    required_feature_flags: tuple[AIProviderFeatureFlag, ...]
    lifecycle_state: AIProviderLifecycleState
    visibility: AIProviderVisibility
    classification: AIProviderClassification
    schema_version: Literal["ai-provider-metadata.v1"] = "ai-provider-metadata.v1"

    def __post_init__(self) -> None:
        scalar_fields = (
            self.identifier,
            self.version,
            self.family,
            self.maximum_request_schema_version,
            self.maximum_response_schema_version,
        )
        if any(not value.strip() for value in scalar_fields):
            raise ValueError("provider metadata identifiers must not be blank")
        self._require_unique_non_empty(
            self.supported_request_schema_versions,
            "request schema versions",
        )
        self._require_unique_non_empty(
            self.supported_response_schema_versions,
            "response schema versions",
        )
        self._require_unique_non_empty(self.execution_capabilities, "execution capabilities")
        self._require_unique_non_empty(self.response_capabilities, "response capabilities")
        self._require_unique_non_empty(self.languages, "languages")
        self._require_unique(self.required_feature_flags, "required feature flags")
        if self.maximum_request_schema_version not in self.supported_request_schema_versions:
            raise ValueError("maximum request schema version must be supported")
        if self.maximum_response_schema_version not in self.supported_response_schema_versions:
            raise ValueError("maximum response schema version must be supported")

    @staticmethod
    def _require_unique(values: tuple[object, ...], field_name: str) -> None:
        if len(set(values)) != len(values):
            raise ValueError(f"{field_name} must be unique")

    @classmethod
    def _require_unique_non_empty(
        cls,
        values: tuple[object, ...],
        field_name: str,
    ) -> None:
        if not values:
            raise ValueError(f"{field_name} must not be empty")
        cls._require_unique(values, field_name)
        if any(isinstance(value, str) and not value.strip() for value in values):
            raise ValueError(f"{field_name} must not contain blank values")


@dataclass(frozen=True, slots=True)
class AIProviderFeatureFlagsV1:
    """Runtime-safe view of existing flags; contains no provider credentials."""

    ai_coaching_enabled: bool = False
    ai_mock_execution_enabled: bool = False
    schema_version: Literal["ai-provider-feature-flags.v1"] = "ai-provider-feature-flags.v1"

    def enabled(self, feature: AIProviderFeatureFlag) -> bool:
        if feature == AIProviderFeatureFlag.AI_COACHING_ENABLED:
            return self.ai_coaching_enabled
        return self.ai_mock_execution_enabled


@dataclass(frozen=True, slots=True)
class AIProviderSelectionRequestV1:
    """Internal deterministic selection requirements for one execution."""

    requested_provider_identifier: str | None
    request_schema_version: str
    accepted_response_schema_versions: tuple[str, ...]
    required_execution_capabilities: tuple[AIProviderExecutionCapability, ...]
    required_response_capabilities: tuple[CoachingCapability, ...]
    language: str
    schema_version: Literal["ai-provider-selection-request.v1"] = "ai-provider-selection-request.v1"

    def __post_init__(self) -> None:
        if (
            self.requested_provider_identifier is not None
            and not self.requested_provider_identifier.strip()
        ):
            raise ValueError("requested provider identifier must not be blank")
        if not self.request_schema_version.strip():
            raise ValueError("request schema version must not be blank")
        if not self.accepted_response_schema_versions:
            raise ValueError("accepted response schema versions must not be empty")
        if len(set(self.accepted_response_schema_versions)) != len(
            self.accepted_response_schema_versions
        ):
            raise ValueError("accepted response schema versions must be unique")
        if len(set(self.required_execution_capabilities)) != len(
            self.required_execution_capabilities
        ):
            raise ValueError("required execution capabilities must be unique")
        if len(set(self.required_response_capabilities)) != len(
            self.required_response_capabilities
        ):
            raise ValueError("required response capabilities must be unique")
        if not self.language.strip():
            raise ValueError("language must not be blank")


@dataclass(frozen=True, slots=True)
class AIProviderCompatibilityFailureV1:
    """One safe compatibility failure without internal configuration details."""

    code: AIProviderCompatibilityFailureCode
    schema_version: Literal["ai-provider-compatibility-failure.v1"] = (
        "ai-provider-compatibility-failure.v1"
    )


@dataclass(frozen=True, slots=True)
class AIProviderHealthV1:
    """Deterministic structural health, never a live external-provider status."""

    provider_identifier: str
    status: AIProviderHealthStatus
    schema_version: Literal["ai-provider-health.v1"] = "ai-provider-health.v1"


@dataclass(frozen=True, slots=True)
class AIProviderRuntimeConfigurationV1:
    """Provider-neutral runtime configuration with no secrets or endpoints."""

    feature_flags: AIProviderFeatureFlagsV1 = field(default_factory=AIProviderFeatureFlagsV1)
    default_provider_identifier: str = "mock-ai-provider.v1"
    schema_version: Literal["ai-provider-runtime-configuration.v1"] = (
        "ai-provider-runtime-configuration.v1"
    )

    def __post_init__(self) -> None:
        if not self.default_provider_identifier.strip():
            raise ValueError("default provider identifier must not be blank")
