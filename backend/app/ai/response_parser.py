"""Strict standard-library parser for structured provider responses."""

import json
from dataclasses import dataclass
from typing import cast
from uuid import UUID

from app.ai.contracts import (
    AI_RAW_RESPONSE_SCHEMA_VERSION,
    AI_RESPONSE_SCHEMA_VERSION,
    AIRawProviderResponseV1,
    AIResponseStatus,
    AIResponseV1,
)

_EXPECTED_KEYS = frozenset(
    {
        "schema_version",
        "provider_identifier",
        "status",
        "request_schema_version",
        "prompt_identifier",
        "prompt_template_version",
        "evidence_event_ids",
        "limitations",
    }
)


@dataclass(frozen=True, slots=True)
class AIResponseParseError(ValueError):
    """Content-safe parsing failure; raw payload is deliberately excluded."""

    code: str = "invalid_provider_response"

    def __str__(self) -> str:
        return self.code


def _nonempty_string(value: object) -> str:
    if not isinstance(value, str) or not value:
        raise AIResponseParseError()
    return value


def _string_tuple(value: object) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
        raise AIResponseParseError()
    return tuple(cast(list[str], value))


class AIResponseParser:
    """Accept only the exact Phase 8 structured placeholder schema."""

    def parse(self, raw: AIRawProviderResponseV1) -> AIResponseV1:
        if raw.schema_version != AI_RAW_RESPONSE_SCHEMA_VERSION:
            raise AIResponseParseError()
        try:
            value = json.loads(raw.payload)
        except (json.JSONDecodeError, TypeError) as error:
            raise AIResponseParseError() from error
        if not isinstance(value, dict) or frozenset(value) != _EXPECTED_KEYS:
            raise AIResponseParseError()
        payload = cast(dict[str, object], value)
        if payload["schema_version"] != AI_RESPONSE_SCHEMA_VERSION:
            raise AIResponseParseError()
        provider_identifier = _nonempty_string(payload["provider_identifier"])
        if provider_identifier != raw.provider_identifier:
            raise AIResponseParseError()
        try:
            status = AIResponseStatus(_nonempty_string(payload["status"]))
            event_ids = tuple(UUID(item) for item in _string_tuple(payload["evidence_event_ids"]))
        except (ValueError, TypeError) as error:
            raise AIResponseParseError() from error
        if len(set(event_ids)) != len(event_ids):
            raise AIResponseParseError()
        limitations = _string_tuple(payload["limitations"])
        if not limitations:
            raise AIResponseParseError()
        return AIResponseV1(
            provider_identifier=provider_identifier,
            status=status,
            request_schema_version=_nonempty_string(payload["request_schema_version"]),
            prompt_identifier=_nonempty_string(payload["prompt_identifier"]),
            prompt_template_version=_nonempty_string(payload["prompt_template_version"]),
            evidence_event_ids=event_ids,
            limitations=limitations,
        )
