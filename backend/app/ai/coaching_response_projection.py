"""Content-free renderer projections for a future accessible UI."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Literal
from uuid import UUID

from app.ai.coaching_response_contracts import StructuredCoachingResponseV1


class CoachingRendererSectionStatus(StrEnum):
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    NOTICE = "notice"


@dataclass(frozen=True, slots=True)
class CoachingRendererSectionV1:
    identifier: str
    heading_localization_key: str
    semantic_label_localization_key: str
    status: CoachingRendererSectionStatus
    item_localization_keys: tuple[str, ...]
    evidence_reference_count: int
    schema_version: Literal["ai-coaching-renderer-section.v1"] = "ai-coaching-renderer-section.v1"


@dataclass(frozen=True, slots=True)
class CoachingRendererProjectionV1:
    response_id: UUID
    locale: str
    sections: tuple[CoachingRendererSectionV1, ...]
    schema_version: Literal["ai-coaching-renderer-projection.v1"] = (
        "ai-coaching-renderer-projection.v1"
    )


class CoachingResponseProjector:
    """Project localization keys and counts, never coaching or evidence content."""

    def project(
        self,
        response: StructuredCoachingResponseV1,
    ) -> CoachingRendererProjectionV1:
        evidence_reference_count = sum(
            len(link.event_ids) + len(link.relationship_ids) + len(link.metric_identifiers)
            for link in response.evidence_links
        )
        sections = (
            CoachingRendererSectionV1(
                identifier="supported_capabilities",
                heading_localization_key="coaching.section.supported.heading",
                semantic_label_localization_key="coaching.section.supported.semantic",
                status=CoachingRendererSectionStatus.AVAILABLE,
                item_localization_keys=tuple(
                    f"coaching.capability.{capability.value}"
                    for capability in response.capabilities.supported
                ),
                evidence_reference_count=0,
            ),
            CoachingRendererSectionV1(
                identifier="unavailable_capabilities",
                heading_localization_key="coaching.section.unavailable.heading",
                semantic_label_localization_key="coaching.section.unavailable.semantic",
                status=CoachingRendererSectionStatus.UNAVAILABLE,
                item_localization_keys=tuple(
                    f"coaching.capability.{item.capability.value}.unavailable"
                    for item in response.capabilities.unavailable
                ),
                evidence_reference_count=0,
            ),
            CoachingRendererSectionV1(
                identifier="explanations",
                heading_localization_key="coaching.section.explanations.heading",
                semantic_label_localization_key="coaching.section.explanations.semantic",
                status=CoachingRendererSectionStatus.UNAVAILABLE,
                item_localization_keys=tuple(
                    explanation.localization_key for explanation in response.explanations
                ),
                evidence_reference_count=evidence_reference_count,
            ),
            CoachingRendererSectionV1(
                identifier="safety_notices",
                heading_localization_key="coaching.section.safety.heading",
                semantic_label_localization_key="coaching.section.safety.semantic",
                status=CoachingRendererSectionStatus.NOTICE,
                item_localization_keys=tuple(
                    notice.localization_key for notice in response.safety_notices
                ),
                evidence_reference_count=sum(
                    len(notice.evidence_link_ids) for notice in response.safety_notices
                ),
            ),
        )
        return CoachingRendererProjectionV1(
            response_id=response.metadata.response_id,
            locale=response.metadata.locale,
            sections=sections,
        )
