"""Strict content-safe JSON codec for structured coaching responses."""

import json
from dataclasses import dataclass
from typing import cast
from uuid import UUID

from app.ai.coaching_response_contracts import (
    AI_COACHING_RESPONSE_SCHEMA_VERSION,
    CoachingCapabilitiesV1,
    CoachingCapability,
    CoachingConfidenceDescriptor,
    CoachingEvidenceLinkV1,
    CoachingExplanationStatus,
    CoachingExplanationV1,
    CoachingResponseMetadataV1,
    CoachingResponseParseFailureCode,
    CoachingResponseParseFailureV1,
    CoachingResponseParseResultV1,
    CoachingResponseParseSuccessV1,
    CoachingResponseProvenanceV1,
    CoachingSafetyNoticeCode,
    CoachingSafetyNoticeV1,
    CoachingSafetySeverity,
    CoachingUnavailableCapabilityV1,
    CoachingUnavailableReason,
    StructuredCoachingResponseV1,
)

_FORBIDDEN_FIELDS = frozenset(
    {
        "message",
        "message_text",
        "text",
        "screenshot",
        "screenshots",
        "image_bytes",
        "ocr",
        "ocr_output",
        "prompt",
        "prompt_text",
        "raw_evidence",
        "evidence_payload",
        "deleted_content",
        "participant_name",
    }
)


@dataclass(frozen=True, slots=True)
class _ParseAbort(Exception):
    code: CoachingResponseParseFailureCode
    field_name: str | None = None


def _mapping(value: object, expected: frozenset[str]) -> dict[str, object]:
    if not isinstance(value, dict) or frozenset(value) != expected:
        raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_SHAPE)
    return cast(dict[str, object], value)


def _sequence(value: object) -> list[object]:
    if not isinstance(value, list):
        raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_SHAPE)
    return cast(list[object], value)


def _string(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE)
    return value


def _uuid(value: object) -> UUID:
    try:
        return UUID(_string(value))
    except ValueError as error:
        raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE) from error


def _string_tuple(value: object) -> tuple[str, ...]:
    return tuple(_string(item) for item in _sequence(value))


def _uuid_tuple(value: object) -> tuple[UUID, ...]:
    return tuple(_uuid(item) for item in _sequence(value))


def _expect_schema(value: object, expected: str) -> None:
    if _string(value) != expected:
        raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE)


def _find_forbidden_field(value: object) -> str | None:
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(key, str) and key.lower() in _FORBIDDEN_FIELDS:
                return key
            nested = _find_forbidden_field(item)
            if nested is not None:
                return nested
    elif isinstance(value, list):
        for item in value:
            nested = _find_forbidden_field(item)
            if nested is not None:
                return nested
    return None


class StructuredCoachingResponseCodec:
    """Serialize once and parse exact schemas without echoing invalid payloads."""

    def serialize(self, response: StructuredCoachingResponseV1) -> str:
        value = {
            "schema_version": response.schema_version,
            "metadata": {
                "schema_version": response.metadata.schema_version,
                "response_id": str(response.metadata.response_id),
                "request_id": str(response.metadata.request_id),
                "locale": response.metadata.locale,
            },
            "capabilities": {
                "schema_version": response.capabilities.schema_version,
                "supported": [capability.value for capability in response.capabilities.supported],
                "unavailable": [
                    {
                        "schema_version": item.schema_version,
                        "capability": item.capability.value,
                        "reason": item.reason.value,
                    }
                    for item in response.capabilities.unavailable
                ],
            },
            "evidence_links": [
                {
                    "schema_version": link.schema_version,
                    "link_id": str(link.link_id),
                    "evidence_package_id": str(link.evidence_package_id),
                    "event_ids": [str(identifier) for identifier in link.event_ids],
                    "relationship_ids": [str(identifier) for identifier in link.relationship_ids],
                    "metric_identifiers": list(link.metric_identifiers),
                    "analytics_schema_version": link.analytics_schema_version,
                    "analytics_calculation_version": (link.analytics_calculation_version),
                }
                for link in response.evidence_links
            ],
            "explanations": [
                {
                    "schema_version": explanation.schema_version,
                    "explanation_id": str(explanation.explanation_id),
                    "capability": explanation.capability.value,
                    "status": explanation.status.value,
                    "localization_key": explanation.localization_key,
                    "evidence_link_ids": [
                        str(identifier) for identifier in explanation.evidence_link_ids
                    ],
                    "confidence": explanation.confidence.value,
                }
                for explanation in response.explanations
            ],
            "safety_notices": [
                {
                    "schema_version": notice.schema_version,
                    "code": notice.code.value,
                    "severity": notice.severity.value,
                    "localization_key": notice.localization_key,
                    "evidence_link_ids": [
                        str(identifier) for identifier in notice.evidence_link_ids
                    ],
                }
                for notice in response.safety_notices
            ],
            "provenance": {
                "schema_version": response.provenance.schema_version,
                "generator_identifier": response.provenance.generator_identifier,
                "source_evidence_schema_version": (
                    response.provenance.source_evidence_schema_version
                ),
                "analytics_schema_version": (response.provenance.analytics_schema_version),
                "analytics_calculation_version": (
                    response.provenance.analytics_calculation_version
                ),
            },
        }
        return json.dumps(value, sort_keys=True, separators=(",", ":"))

    def parse(self, payload: str) -> CoachingResponseParseResultV1:
        try:
            value = json.loads(payload)
        except (json.JSONDecodeError, TypeError):
            return CoachingResponseParseFailureV1(CoachingResponseParseFailureCode.INVALID_JSON)
        forbidden = _find_forbidden_field(value)
        if forbidden is not None:
            return CoachingResponseParseFailureV1(
                CoachingResponseParseFailureCode.FORBIDDEN_FIELD,
                forbidden,
            )
        try:
            response = self._parse_response(value)
        except _ParseAbort as error:
            return CoachingResponseParseFailureV1(
                error.code,
                error.field_name,
            )
        return CoachingResponseParseSuccessV1(response=response)

    def _parse_response(self, value: object) -> StructuredCoachingResponseV1:
        root = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "metadata",
                    "capabilities",
                    "evidence_links",
                    "explanations",
                    "safety_notices",
                    "provenance",
                }
            ),
        )
        _expect_schema(
            root["schema_version"],
            AI_COACHING_RESPONSE_SCHEMA_VERSION,
        )
        return StructuredCoachingResponseV1(
            metadata=self._parse_metadata(root["metadata"]),
            capabilities=self._parse_capabilities(root["capabilities"]),
            evidence_links=tuple(
                self._parse_evidence_link(item) for item in _sequence(root["evidence_links"])
            ),
            explanations=tuple(
                self._parse_explanation(item) for item in _sequence(root["explanations"])
            ),
            safety_notices=tuple(
                self._parse_notice(item) for item in _sequence(root["safety_notices"])
            ),
            provenance=self._parse_provenance(root["provenance"]),
        )

    def _parse_metadata(self, value: object) -> CoachingResponseMetadataV1:
        item = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "response_id",
                    "request_id",
                    "locale",
                }
            ),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-response-metadata.v1",
        )
        return CoachingResponseMetadataV1(
            response_id=_uuid(item["response_id"]),
            request_id=_uuid(item["request_id"]),
            locale=_string(item["locale"]),
        )

    def _parse_capabilities(self, value: object) -> CoachingCapabilitiesV1:
        item = _mapping(
            value,
            frozenset({"schema_version", "supported", "unavailable"}),
        )
        _expect_schema(item["schema_version"], "ai-coaching-capabilities.v1")
        try:
            supported = tuple(
                CoachingCapability(_string(capability))
                for capability in _sequence(item["supported"])
            )
            unavailable = tuple(
                self._parse_unavailable(capability) for capability in _sequence(item["unavailable"])
            )
        except ValueError as error:
            raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE) from error
        return CoachingCapabilitiesV1(
            supported=supported,
            unavailable=unavailable,
        )

    def _parse_unavailable(
        self,
        value: object,
    ) -> CoachingUnavailableCapabilityV1:
        item = _mapping(
            value,
            frozenset({"schema_version", "capability", "reason"}),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-unavailable-capability.v1",
        )
        try:
            return CoachingUnavailableCapabilityV1(
                capability=CoachingCapability(_string(item["capability"])),
                reason=CoachingUnavailableReason(_string(item["reason"])),
            )
        except ValueError as error:
            raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE) from error

    def _parse_evidence_link(self, value: object) -> CoachingEvidenceLinkV1:
        item = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "link_id",
                    "evidence_package_id",
                    "event_ids",
                    "relationship_ids",
                    "metric_identifiers",
                    "analytics_schema_version",
                    "analytics_calculation_version",
                }
            ),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-evidence-link.v1",
        )
        return CoachingEvidenceLinkV1(
            link_id=_uuid(item["link_id"]),
            evidence_package_id=_uuid(item["evidence_package_id"]),
            event_ids=_uuid_tuple(item["event_ids"]),
            relationship_ids=_uuid_tuple(item["relationship_ids"]),
            metric_identifiers=_string_tuple(item["metric_identifiers"]),
            analytics_schema_version=_string(item["analytics_schema_version"]),
            analytics_calculation_version=_string(item["analytics_calculation_version"]),
        )

    def _parse_explanation(self, value: object) -> CoachingExplanationV1:
        item = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "explanation_id",
                    "capability",
                    "status",
                    "localization_key",
                    "evidence_link_ids",
                    "confidence",
                }
            ),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-explanation.v1",
        )
        try:
            return CoachingExplanationV1(
                explanation_id=_uuid(item["explanation_id"]),
                capability=CoachingCapability(_string(item["capability"])),
                status=CoachingExplanationStatus(_string(item["status"])),
                localization_key=_string(item["localization_key"]),
                evidence_link_ids=_uuid_tuple(item["evidence_link_ids"]),
                confidence=CoachingConfidenceDescriptor(_string(item["confidence"])),
            )
        except ValueError as error:
            raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE) from error

    def _parse_notice(self, value: object) -> CoachingSafetyNoticeV1:
        item = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "code",
                    "severity",
                    "localization_key",
                    "evidence_link_ids",
                }
            ),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-safety-notice.v1",
        )
        try:
            return CoachingSafetyNoticeV1(
                code=CoachingSafetyNoticeCode(_string(item["code"])),
                severity=CoachingSafetySeverity(_string(item["severity"])),
                localization_key=_string(item["localization_key"]),
                evidence_link_ids=_uuid_tuple(item["evidence_link_ids"]),
            )
        except ValueError as error:
            raise _ParseAbort(CoachingResponseParseFailureCode.INVALID_VALUE) from error

    def _parse_provenance(
        self,
        value: object,
    ) -> CoachingResponseProvenanceV1:
        item = _mapping(
            value,
            frozenset(
                {
                    "schema_version",
                    "generator_identifier",
                    "source_evidence_schema_version",
                    "analytics_schema_version",
                    "analytics_calculation_version",
                }
            ),
        )
        _expect_schema(
            item["schema_version"],
            "ai-coaching-provenance.v1",
        )
        return CoachingResponseProvenanceV1(
            generator_identifier=_string(item["generator_identifier"]),
            source_evidence_schema_version=_string(item["source_evidence_schema_version"]),
            analytics_schema_version=_string(item["analytics_schema_version"]),
            analytics_calculation_version=_string(item["analytics_calculation_version"]),
        )
