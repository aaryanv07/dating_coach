"""Provider boundary and injectable deterministic Phase 8 mock."""

import json
from typing import Protocol

from app.ai.contracts import (
    AI_RESPONSE_SCHEMA_VERSION,
    AIRawProviderResponseV1,
    AIRequestV1,
)

MOCK_AI_PROVIDER_IDENTIFIER = "mock-ai-provider.v1"


class AIProvider(Protocol):
    """External-provider seam. Phase 8 supplies no network implementation."""

    @property
    def identifier(self) -> str: ...

    async def complete(self, request: AIRequestV1) -> AIRawProviderResponseV1: ...


class MockAIProvider:
    """Deterministic test provider that generates no coaching content."""

    @property
    def identifier(self) -> str:
        return MOCK_AI_PROVIDER_IDENTIFIER

    async def complete(self, request: AIRequestV1) -> AIRawProviderResponseV1:
        payload = json.dumps(
            {
                "schema_version": AI_RESPONSE_SCHEMA_VERSION,
                "provider_identifier": self.identifier,
                "status": "foundation_placeholder",
                "request_schema_version": request.schema_version,
                "prompt_identifier": request.template.identifier,
                "prompt_template_version": request.template.template_version,
                "evidence_event_ids": [
                    str(event.event_id) for event in request.evidence.context.events
                ],
                "limitations": [
                    "mock_foundation_only",
                    "no_coaching_generated",
                ],
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        return AIRawProviderResponseV1(
            payload=payload,
            provider_identifier=self.identifier,
        )
