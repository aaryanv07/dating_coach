"""Deterministic provider selection, compatibility, health, and construction."""

from dataclasses import dataclass
from typing import Literal

from app.ai.provider import MOCK_AI_PROVIDER_IDENTIFIER, AIProvider, MockAIProvider
from app.ai.provider_contracts import (
    AIProviderClassification,
    AIProviderCompatibilityFailureCode,
    AIProviderCompatibilityFailureV1,
    AIProviderFeatureFlagsV1,
    AIProviderHealthStatus,
    AIProviderHealthV1,
    AIProviderLifecycleState,
    AIProviderMetadataV1,
    AIProviderRuntimeConfigurationV1,
    AIProviderSelectionRequestV1,
)
from app.ai.provider_registry import AIProviderRegistry, build_default_provider_registry


@dataclass(frozen=True, slots=True)
class AIProviderSelectionV1:
    """Successful deterministic metadata selection."""

    metadata: AIProviderMetadataV1
    schema_version: Literal["ai-provider-selection.v1"] = "ai-provider-selection.v1"


@dataclass(frozen=True, slots=True)
class AIProviderSelectionRejectedV1:
    """Content-free deterministic selection rejection."""

    provider_identifier: str
    failures: tuple[AIProviderCompatibilityFailureV1, ...]
    schema_version: Literal["ai-provider-selection-rejected.v1"] = (
        "ai-provider-selection-rejected.v1"
    )


type AIProviderSelectionResultV1 = AIProviderSelectionV1 | AIProviderSelectionRejectedV1


@dataclass(frozen=True, slots=True)
class AIProviderCreatedV1:
    """Internal factory result; the provider instance is never transported."""

    provider: AIProvider
    metadata: AIProviderMetadataV1
    health: AIProviderHealthV1
    schema_version: Literal["ai-provider-created.v1"] = "ai-provider-created.v1"


@dataclass(frozen=True, slots=True)
class AIProviderCreationRejectedV1:
    """Stable factory rejection without configuration or provider details."""

    provider_identifier: str
    failures: tuple[AIProviderCompatibilityFailureV1, ...]
    schema_version: Literal["ai-provider-creation-rejected.v1"] = "ai-provider-creation-rejected.v1"


type AIProviderCreationResultV1 = AIProviderCreatedV1 | AIProviderCreationRejectedV1


class AIProviderCompatibilityValidator:
    """Validate immutable metadata against one internal execution request."""

    def validate(
        self,
        metadata: AIProviderMetadataV1,
        request: AIProviderSelectionRequestV1,
        flags: AIProviderFeatureFlagsV1,
    ) -> tuple[AIProviderCompatibilityFailureV1, ...]:
        failures: list[AIProviderCompatibilityFailureV1] = []

        def reject(code: AIProviderCompatibilityFailureCode) -> None:
            failures.append(AIProviderCompatibilityFailureV1(code))

        if metadata.lifecycle_state != AIProviderLifecycleState.ACTIVE:
            reject(AIProviderCompatibilityFailureCode.PROVIDER_INACTIVE)
        if (
            metadata.classification != AIProviderClassification.MOCK
            or metadata.identifier != MOCK_AI_PROVIDER_IDENTIFIER
        ):
            reject(AIProviderCompatibilityFailureCode.PROVIDER_NOT_MOCK)
        if request.request_schema_version not in metadata.supported_request_schema_versions:
            reject(AIProviderCompatibilityFailureCode.REQUEST_SCHEMA_UNSUPPORTED)
        if not any(
            version in metadata.supported_response_schema_versions
            for version in request.accepted_response_schema_versions
        ):
            reject(AIProviderCompatibilityFailureCode.RESPONSE_SCHEMA_UNSUPPORTED)
        if not set(request.required_execution_capabilities).issubset(
            metadata.execution_capabilities
        ):
            reject(AIProviderCompatibilityFailureCode.EXECUTION_CAPABILITY_UNSUPPORTED)
        if not set(request.required_response_capabilities).issubset(metadata.response_capabilities):
            reject(AIProviderCompatibilityFailureCode.RESPONSE_CAPABILITY_UNSUPPORTED)
        if request.language not in metadata.languages:
            reject(AIProviderCompatibilityFailureCode.LANGUAGE_UNSUPPORTED)
        if any(not flags.enabled(flag) for flag in metadata.required_feature_flags):
            reject(AIProviderCompatibilityFailureCode.FEATURE_FLAG_DISABLED)
        return tuple(failures)


class AIProviderStructuralHealthEvaluator:
    """Derive structural availability without I/O, clocks, or live probes."""

    def evaluate(
        self,
        metadata: AIProviderMetadataV1,
        flags: AIProviderFeatureFlagsV1,
    ) -> AIProviderHealthV1:
        if metadata.lifecycle_state != AIProviderLifecycleState.ACTIVE:
            status = AIProviderHealthStatus.INACTIVE
        elif (
            metadata.classification != AIProviderClassification.MOCK
            or metadata.identifier != MOCK_AI_PROVIDER_IDENTIFIER
        ):
            status = AIProviderHealthStatus.UNAVAILABLE
        elif any(not flags.enabled(flag) for flag in metadata.required_feature_flags):
            status = AIProviderHealthStatus.DISABLED
        else:
            status = AIProviderHealthStatus.AVAILABLE
        return AIProviderHealthV1(
            provider_identifier=metadata.identifier,
            status=status,
        )


class DeterministicAIProviderSelectionPolicy:
    """Select the explicit identifier or the configured default; never fall back."""

    def select(
        self,
        registry: AIProviderRegistry,
        request: AIProviderSelectionRequestV1,
        configuration: AIProviderRuntimeConfigurationV1,
        validator: AIProviderCompatibilityValidator,
    ) -> AIProviderSelectionResultV1:
        identifier = (
            request.requested_provider_identifier or configuration.default_provider_identifier
        )
        metadata = registry.get(identifier)
        if metadata is None:
            return AIProviderSelectionRejectedV1(
                provider_identifier=identifier,
                failures=(
                    AIProviderCompatibilityFailureV1(
                        AIProviderCompatibilityFailureCode.PROVIDER_UNSUPPORTED
                    ),
                ),
            )
        failures = validator.validate(
            metadata,
            request,
            configuration.feature_flags,
        )
        if failures:
            return AIProviderSelectionRejectedV1(
                provider_identifier=identifier,
                failures=failures,
            )
        return AIProviderSelectionV1(metadata)


class AIProviderFactory:
    """Create only the deterministic mock after all fail-closed checks pass."""

    def __init__(
        self,
        registry: AIProviderRegistry,
        configuration: AIProviderRuntimeConfigurationV1,
        *,
        selection_policy: DeterministicAIProviderSelectionPolicy | None = None,
        compatibility_validator: AIProviderCompatibilityValidator | None = None,
        health_evaluator: AIProviderStructuralHealthEvaluator | None = None,
    ) -> None:
        self._registry = registry
        self._configuration = configuration
        self._selection_policy = selection_policy or (DeterministicAIProviderSelectionPolicy())
        self._compatibility_validator = compatibility_validator or (
            AIProviderCompatibilityValidator()
        )
        self._health_evaluator = health_evaluator or (AIProviderStructuralHealthEvaluator())

    @classmethod
    def default(
        cls,
        *,
        ai_coaching_enabled: bool = False,
        ai_mock_execution_enabled: bool = False,
    ) -> "AIProviderFactory":
        return cls(
            build_default_provider_registry(),
            AIProviderRuntimeConfigurationV1(
                feature_flags=AIProviderFeatureFlagsV1(
                    ai_coaching_enabled=ai_coaching_enabled,
                    ai_mock_execution_enabled=ai_mock_execution_enabled,
                )
            ),
        )

    def create(
        self,
        request: AIProviderSelectionRequestV1,
    ) -> AIProviderCreationResultV1:
        selection = self._selection_policy.select(
            self._registry,
            request,
            self._configuration,
            self._compatibility_validator,
        )
        if isinstance(selection, AIProviderSelectionRejectedV1):
            return AIProviderCreationRejectedV1(
                provider_identifier=selection.provider_identifier,
                failures=selection.failures,
            )
        metadata = selection.metadata
        health = self._health_evaluator.evaluate(
            metadata,
            self._configuration.feature_flags,
        )
        if health.status != AIProviderHealthStatus.AVAILABLE:
            return AIProviderCreationRejectedV1(
                provider_identifier=metadata.identifier,
                failures=(
                    AIProviderCompatibilityFailureV1(
                        AIProviderCompatibilityFailureCode.PROVIDER_UNAVAILABLE
                    ),
                ),
            )
        if (
            metadata.identifier != MOCK_AI_PROVIDER_IDENTIFIER
            or metadata.classification != AIProviderClassification.MOCK
        ):
            return AIProviderCreationRejectedV1(
                provider_identifier=metadata.identifier,
                failures=(
                    AIProviderCompatibilityFailureV1(
                        AIProviderCompatibilityFailureCode.PROVIDER_NOT_MOCK
                    ),
                ),
            )
        return AIProviderCreatedV1(
            provider=MockAIProvider(),
            metadata=metadata,
            health=health,
        )
