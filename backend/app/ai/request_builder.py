"""Deterministic immutable AI request construction."""

from uuid import UUID

from app.ai.contracts import (
    AIEvidencePackageV1,
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestV1,
)


class AIRequestBuilder:
    """Build a provider-neutral request after safety validation."""

    def build(
        self,
        request_id: UUID,
        template: AIPromptTemplateV1,
        intent: AIRequestIntentV1,
        evidence: AIEvidencePackageV1,
    ) -> AIRequestV1:
        return AIRequestV1(
            request_id=request_id,
            template=template,
            intent=intent,
            evidence=evidence,
        )
