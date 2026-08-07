"""Closed, immutable metadata registry for AI provider discovery."""

from collections.abc import Iterable, Iterator
from types import MappingProxyType

from app.ai.coaching_response_contracts import CoachingCapability
from app.ai.contracts import AI_REQUEST_SCHEMA_VERSION
from app.ai.provider import MOCK_AI_PROVIDER_IDENTIFIER
from app.ai.provider_contracts import (
    AIProviderClassification,
    AIProviderExecutionCapability,
    AIProviderFeatureFlag,
    AIProviderLifecycleState,
    AIProviderMetadataV1,
    AIProviderVisibility,
)

_MOCK_RESPONSE_SCHEMA_VERSION = "ai-coaching-response.v1"


class AIProviderRegistrationError(ValueError):
    """Content-free registry construction failure."""


class AIProviderRegistry:
    """Immutable identifier-to-metadata registry with closed Phase 12 rules."""

    __slots__ = ("_metadata_by_identifier", "_ordered_metadata")

    def __init__(self, registrations: Iterable[AIProviderMetadataV1]) -> None:
        ordered = tuple(registrations)
        metadata_by_identifier: dict[str, AIProviderMetadataV1] = {}
        for metadata in ordered:
            if metadata.identifier in metadata_by_identifier:
                raise AIProviderRegistrationError("duplicate provider identifier")
            self._validate_registration(metadata)
            metadata_by_identifier[metadata.identifier] = metadata
        if not metadata_by_identifier:
            raise AIProviderRegistrationError("provider registry must not be empty")
        self._ordered_metadata = ordered
        self._metadata_by_identifier = MappingProxyType(metadata_by_identifier)

    @staticmethod
    def _validate_registration(metadata: AIProviderMetadataV1) -> None:
        if metadata.lifecycle_state == AIProviderLifecycleState.ACTIVE and (
            metadata.classification != AIProviderClassification.MOCK
            or metadata.identifier != MOCK_AI_PROVIDER_IDENTIFIER
        ):
            raise AIProviderRegistrationError("only the deterministic mock provider may be active")
        if metadata.classification == AIProviderClassification.MOCK and (
            metadata.identifier != MOCK_AI_PROVIDER_IDENTIFIER
        ):
            raise AIProviderRegistrationError("mock provider identifier is unsupported")
        if (
            metadata.classification == AIProviderClassification.PRODUCTION
            and metadata.lifecycle_state != AIProviderLifecycleState.INACTIVE
        ):
            raise AIProviderRegistrationError("production provider metadata must remain inactive")

    def get(self, identifier: str) -> AIProviderMetadataV1 | None:
        return self._metadata_by_identifier.get(identifier)

    def __iter__(self) -> Iterator[AIProviderMetadataV1]:
        return iter(self._ordered_metadata)

    def __len__(self) -> int:
        return len(self._ordered_metadata)


def deterministic_mock_provider_metadata() -> AIProviderMetadataV1:
    """Return the sole executable Phase 12 provider registration."""

    return AIProviderMetadataV1(
        identifier=MOCK_AI_PROVIDER_IDENTIFIER,
        version="1.0.0",
        family="convocoach-deterministic-foundation",
        supported_request_schema_versions=(AI_REQUEST_SCHEMA_VERSION,),
        supported_response_schema_versions=(_MOCK_RESPONSE_SCHEMA_VERSION,),
        execution_capabilities=(AIProviderExecutionCapability.FOUNDATION_PLACEHOLDER,),
        response_capabilities=(
            CoachingCapability.RESPONSE_SCHEMA,
            CoachingCapability.EVIDENCE_REFERENCES,
            CoachingCapability.EXPLANATION_PLACEHOLDERS,
            CoachingCapability.SAFETY_NOTICES,
        ),
        languages=("en",),
        maximum_request_schema_version=AI_REQUEST_SCHEMA_VERSION,
        maximum_response_schema_version=_MOCK_RESPONSE_SCHEMA_VERSION,
        required_feature_flags=(
            AIProviderFeatureFlag.AI_COACHING_ENABLED,
            AIProviderFeatureFlag.AI_MOCK_EXECUTION_ENABLED,
        ),
        lifecycle_state=AIProviderLifecycleState.ACTIVE,
        visibility=AIProviderVisibility.INTERNAL,
        classification=AIProviderClassification.MOCK,
    )


def build_default_provider_registry() -> AIProviderRegistry:
    """Build the closed registry; no external provider is imported or initialized."""

    return AIProviderRegistry((deterministic_mock_provider_metadata(),))
