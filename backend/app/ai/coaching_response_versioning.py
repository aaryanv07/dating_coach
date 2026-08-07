"""Deterministic version negotiation for renderer and producer boundaries."""

from dataclasses import dataclass
from typing import Literal

from app.ai.coaching_response_contracts import AI_COACHING_RESPONSE_SCHEMA_VERSION


@dataclass(frozen=True, slots=True)
class CoachingResponseVersionNegotiationV1:
    selected_version: str | None
    supported_versions: tuple[str, ...]
    schema_version: Literal["ai-coaching-response-version-negotiation.v1"] = (
        "ai-coaching-response-version-negotiation.v1"
    )

    @property
    def supported(self) -> bool:
        return self.selected_version is not None


class CoachingResponseVersionNegotiator:
    """Select the first caller-preferred version supported by this runtime."""

    supported_versions = (AI_COACHING_RESPONSE_SCHEMA_VERSION,)

    def negotiate(
        self,
        accepted_versions: tuple[str, ...],
    ) -> CoachingResponseVersionNegotiationV1:
        selected = next(
            (version for version in accepted_versions if version in self.supported_versions),
            None,
        )
        return CoachingResponseVersionNegotiationV1(
            selected_version=selected,
            supported_versions=self.supported_versions,
        )
