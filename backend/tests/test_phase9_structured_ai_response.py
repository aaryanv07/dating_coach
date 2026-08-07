"""Phase 9 structured AI response foundation tests."""

import json
from collections.abc import Callable
from dataclasses import FrozenInstanceError, replace
from typing import Any
from uuid import UUID

import pytest

from app.ai.coaching_response_codec import StructuredCoachingResponseCodec
from app.ai.coaching_response_contracts import (
    AI_COACHING_RESPONSE_SCHEMA_VERSION,
    CoachingCapability,
    CoachingEvidenceLinkV1,
    CoachingResponseParseFailureCode,
    CoachingResponseParseFailureV1,
    CoachingResponseParseSuccessV1,
    CoachingResponseValidationFailureCode,
    CoachingUnavailableCapabilityV1,
    CoachingUnavailableReason,
    StructuredCoachingResponseV1,
)
from app.ai.coaching_response_mock import DeterministicCoachingResponseMock
from app.ai.coaching_response_projection import (
    CoachingRendererSectionStatus,
    CoachingResponseProjector,
)
from app.ai.coaching_response_validation import (
    StructuredCoachingResponseValidator,
)
from app.ai.coaching_response_versioning import (
    CoachingResponseVersionNegotiator,
)
from app.ai.contracts import (
    AIAnalyticsMetricEvidenceV1,
    AIConversationContextV1,
    AIEventEvidenceV1,
    AIEvidencePackageV1,
    AIRelationshipEvidenceV1,
)
from app.domain.conversation_analytics import (
    AnalyticsReviewStatus,
    DeterministicConfidence,
    MetricUnit,
    QualityMetadataV1,
)
from app.domain.conversation_events import (
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
)

PRIVATE_SENTINEL = "private synthetic message content"


def _uuid(value: int) -> UUID:
    return UUID(f"00000000-0000-4000-8000-{value:012d}")


def _quality() -> QualityMetadataV1:
    return QualityMetadataV1(
        supported=True,
        unsupported=False,
        confidence=DeterministicConfidence.COMPLETE,
        missing_data=(),
        review_status=AnalyticsReviewStatus.CONFIRMED,
        incomplete_timeline=False,
    )


def _evidence() -> AIEvidencePackageV1:
    return AIEvidencePackageV1(
        context=AIConversationContextV1(
            events=(
                AIEventEvidenceV1(
                    event_id=_uuid(1),
                    position=0,
                    event_type=ConversationEventType.TEXT_MESSAGE,
                    speaker=ConversationEventSpeaker.USER,
                    has_exact_timestamp=True,
                ),
                AIEventEvidenceV1(
                    event_id=_uuid(2),
                    position=1,
                    event_type=ConversationEventType.TEXT_MESSAGE,
                    speaker=ConversationEventSpeaker.OTHER,
                    has_exact_timestamp=True,
                ),
            ),
            relationships=(
                AIRelationshipEvidenceV1(
                    relationship_id=_uuid(3),
                    source_event_id=_uuid(2),
                    target_event_id=_uuid(1),
                    relationship_type=ConversationEventRelationshipType.REPLY_TARGET,
                ),
            ),
            source_event_schema_version="conversation-events.v1",
        ),
        analytics=(
            AIAnalyticsMetricEvidenceV1(
                identifier="messages.total",
                value=2,
                unit=MetricUnit.COUNT,
                event_ids=(_uuid(1), _uuid(2)),
                relationship_ids=(),
                quality=_quality(),
            ),
            AIAnalyticsMetricEvidenceV1(
                identifier="structure.unknown_events",
                value=0,
                unit=MetricUnit.COUNT,
                event_ids=(),
                relationship_ids=(),
                quality=_quality(),
            ),
        ),
        analytics_schema_version="conversation-analytics.v1",
        analytics_calculation_version="deterministic-conversation-analytics.v1",
    )


def _response() -> StructuredCoachingResponseV1:
    return DeterministicCoachingResponseMock().generate(
        response_id=_uuid(10),
        request_id=_uuid(11),
        evidence_package_id=_uuid(12),
        evidence=_evidence(),
    )


def _failure_codes(
    response: StructuredCoachingResponseV1 | None = None,
) -> set[CoachingResponseValidationFailureCode]:
    result = StructuredCoachingResponseValidator().validate(
        response or _response(),
        evidence_package_id=_uuid(12),
        evidence=_evidence(),
    )
    return {failure.code for failure in result}


def test_mock_response_is_deterministic_immutable_and_placeholder_only() -> None:
    first = _response()
    second = _response()

    assert first == second
    assert first.schema_version == AI_COACHING_RESPONSE_SCHEMA_VERSION
    assert {item.capability for item in first.capabilities.unavailable} >= {
        CoachingCapability.COACHING_GUIDANCE,
        CoachingCapability.RECOMMENDATIONS,
        CoachingCapability.REPLY_DRAFTING,
    }
    assert "advice" not in repr(first).lower()
    assert PRIVATE_SENTINEL not in repr(first)
    with pytest.raises(FrozenInstanceError):
        delattr(first, "explanations")


def test_mock_response_validates_against_exact_evidence_scope() -> None:
    assert _failure_codes() == set()


def test_validator_rejects_deleted_rejected_or_missing_structural_references() -> None:
    response = _response()
    link = response.evidence_links[0]
    invalid_link = replace(
        link,
        event_ids=(*link.event_ids, _uuid(90)),
        relationship_ids=(*link.relationship_ids, _uuid(91)),
        metric_identifiers=(*link.metric_identifiers, "missing.metric"),
    )
    invalid = replace(response, evidence_links=(invalid_link,))

    codes = _failure_codes(invalid)

    assert CoachingResponseValidationFailureCode.FORBIDDEN_EVENT_REFERENCE in codes
    assert CoachingResponseValidationFailureCode.FORBIDDEN_RELATIONSHIP_REFERENCE in codes
    assert CoachingResponseValidationFailureCode.FORBIDDEN_METRIC_REFERENCE in codes


def test_validator_rejects_missing_links_versions_and_package_mismatch() -> None:
    response = _response()
    link = replace(
        response.evidence_links[0],
        evidence_package_id=_uuid(99),
        analytics_schema_version="conversation-analytics.v0",
    )
    explanation = replace(
        response.explanations[0],
        evidence_link_ids=(_uuid(98),),
    )
    invalid = replace(
        response,
        evidence_links=(link,),
        explanations=(explanation,),
    )

    codes = _failure_codes(invalid)

    assert CoachingResponseValidationFailureCode.EVIDENCE_PACKAGE_MISMATCH in codes
    assert CoachingResponseValidationFailureCode.ANALYTICS_VERSION_MISMATCH in codes
    assert CoachingResponseValidationFailureCode.MISSING_EVIDENCE_REFERENCE in codes


def test_validator_rejects_capability_conflicts_and_invalid_localization() -> None:
    response = _response()
    conflicting = CoachingUnavailableCapabilityV1(
        capability=CoachingCapability.RESPONSE_SCHEMA,
        reason=CoachingUnavailableReason.NOT_IMPLEMENTED,
    )
    invalid = replace(
        response,
        capabilities=replace(
            response.capabilities,
            unavailable=(*response.capabilities.unavailable, conflicting),
        ),
        explanations=(
            replace(
                response.explanations[0],
                localization_key="private.free.form.text",
            ),
        ),
    )

    codes = _failure_codes(invalid)

    assert CoachingResponseValidationFailureCode.DUPLICATE_IDENTIFIER in codes
    assert CoachingResponseValidationFailureCode.CAPABILITY_STATUS_CONFLICT in codes
    assert CoachingResponseValidationFailureCode.INVALID_LOCALIZATION_KEY in codes


def test_version_negotiation_is_deterministic_and_explicitly_unsupported() -> None:
    negotiator = CoachingResponseVersionNegotiator()

    supported = negotiator.negotiate(
        ("ai-coaching-response.v2", AI_COACHING_RESPONSE_SCHEMA_VERSION)
    )
    unsupported = negotiator.negotiate(("ai-coaching-response.v2",))

    assert supported.selected_version == AI_COACHING_RESPONSE_SCHEMA_VERSION
    assert supported.supported is True
    assert unsupported.selected_version is None
    assert unsupported.supported is False
    assert unsupported.supported_versions == (AI_COACHING_RESPONSE_SCHEMA_VERSION,)


def test_codec_round_trip_is_exact_and_deterministic() -> None:
    codec = StructuredCoachingResponseCodec()
    response = _response()

    first = codec.serialize(response)
    second = codec.serialize(response)
    parsed = codec.parse(first)

    assert first == second
    assert isinstance(parsed, CoachingResponseParseSuccessV1)
    assert parsed.response == response
    assert PRIVATE_SENTINEL not in first
    assert "prompt" not in first.lower()
    assert "message_text" not in first


@pytest.mark.parametrize(
    ("mutator", "expected"),
    [
        (
            lambda value: value.update({"message_text": PRIVATE_SENTINEL}),
            CoachingResponseParseFailureCode.FORBIDDEN_FIELD,
        ),
        (
            lambda value: value["capabilities"]["supported"].append("unknown_capability"),
            CoachingResponseParseFailureCode.INVALID_VALUE,
        ),
        (
            lambda value: value.update({"unexpected": "field"}),
            CoachingResponseParseFailureCode.INVALID_SHAPE,
        ),
        (
            lambda value: value.update({"schema_version": "ai-coaching-response.v0"}),
            CoachingResponseParseFailureCode.INVALID_VALUE,
        ),
    ],
)
def test_codec_returns_content_safe_structured_failures(
    mutator: Callable[[dict[str, Any]], None],
    expected: CoachingResponseParseFailureCode,
) -> None:
    codec = StructuredCoachingResponseCodec()
    value: dict[str, Any] = json.loads(codec.serialize(_response()))
    mutator(value)

    result = codec.parse(json.dumps(value))

    assert isinstance(result, CoachingResponseParseFailureV1)
    assert result.code == expected
    assert PRIVATE_SENTINEL not in repr(result)


def test_codec_rejects_invalid_json_without_echoing_it() -> None:
    result = StructuredCoachingResponseCodec().parse('{"message_text":"' + PRIVATE_SENTINEL)

    assert result == CoachingResponseParseFailureV1(CoachingResponseParseFailureCode.INVALID_JSON)
    assert PRIVATE_SENTINEL not in repr(result)


def test_renderer_projection_contains_only_localization_keys_and_counts() -> None:
    projection = CoachingResponseProjector().project(_response())

    assert projection.response_id == _uuid(10)
    assert [section.status for section in projection.sections] == [
        CoachingRendererSectionStatus.AVAILABLE,
        CoachingRendererSectionStatus.UNAVAILABLE,
        CoachingRendererSectionStatus.UNAVAILABLE,
        CoachingRendererSectionStatus.NOTICE,
    ]
    assert all(section.semantic_label_localization_key for section in projection.sections)
    assert projection.sections[2].evidence_reference_count == 5
    assert PRIVATE_SENTINEL not in repr(projection)
    assert "advice" not in repr(projection).lower()


def test_duplicate_response_section_identifiers_are_rejected() -> None:
    response = _response()
    duplicate_link = CoachingEvidenceLinkV1(
        link_id=response.evidence_links[0].link_id,
        evidence_package_id=_uuid(12),
        event_ids=(),
        relationship_ids=(),
        metric_identifiers=(),
        analytics_schema_version="conversation-analytics.v1",
        analytics_calculation_version="deterministic-conversation-analytics.v1",
    )

    codes = _failure_codes(
        replace(response, evidence_links=(*response.evidence_links, duplicate_link))
    )

    assert CoachingResponseValidationFailureCode.DUPLICATE_IDENTIFIER in codes
