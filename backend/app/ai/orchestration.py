"""Feature-gated provider orchestration with no API, persistence, or network path."""

from uuid import UUID

from app.ai.contracts import (
    AIOrchestrationCompletedV1,
    AIOrchestrationDisabledV1,
    AIOrchestrationProcessingFailureV1,
    AIOrchestrationRejectedV1,
    AIOrchestrationResultV1,
    AIProcessingFailureCode,
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestRequirementsV1,
)
from app.ai.evidence import AIEvidenceBuilder
from app.ai.provider import AIProvider
from app.ai.request_builder import AIRequestBuilder
from app.ai.response_parser import AIResponseParseError, AIResponseParser
from app.ai.safety import AIRequestSafetyValidator
from app.domain.conversation_analytics import AnalyticsInputV1, AnalyticsResultV1


class AIOrchestrator:
    """The only supported provider call path; disabled by default."""

    def __init__(
        self,
        provider: AIProvider,
        *,
        feature_enabled: bool = False,
        evidence_builder: AIEvidenceBuilder | None = None,
        safety_validator: AIRequestSafetyValidator | None = None,
        request_builder: AIRequestBuilder | None = None,
        response_parser: AIResponseParser | None = None,
    ) -> None:
        self._provider = provider
        self._feature_enabled = feature_enabled
        self._evidence_builder = evidence_builder or AIEvidenceBuilder()
        self._safety_validator = safety_validator or AIRequestSafetyValidator()
        self._request_builder = request_builder or AIRequestBuilder()
        self._response_parser = response_parser or AIResponseParser()

    async def execute(
        self,
        *,
        request_id: UUID,
        source: AnalyticsInputV1,
        analytics: AnalyticsResultV1,
        requirements: AIRequestRequirementsV1,
        template: AIPromptTemplateV1,
        intent: AIRequestIntentV1,
    ) -> AIOrchestrationResultV1:
        if not self._feature_enabled:
            return AIOrchestrationDisabledV1()

        evidence = self._evidence_builder.build(
            source.event_sequence,
            analytics,
            requirements,
        )
        failures = self._safety_validator.validate(
            source,
            evidence,
            requirements,
            template,
            intent,
        )
        if failures:
            return AIOrchestrationRejectedV1(failures=failures)
        request = self._request_builder.build(
            request_id,
            template,
            intent,
            evidence,
        )
        try:
            raw_response = await self._provider.complete(request)
        except Exception:
            return AIOrchestrationProcessingFailureV1(AIProcessingFailureCode.PROVIDER_FAILURE)
        try:
            response = self._response_parser.parse(raw_response)
        except AIResponseParseError:
            return AIOrchestrationProcessingFailureV1(
                AIProcessingFailureCode.INVALID_PROVIDER_RESPONSE
            )

        packaged_event_ids = {event.event_id for event in evidence.context.events}
        if (
            response.provider_identifier != self._provider.identifier
            or response.request_schema_version != request.schema_version
            or response.prompt_identifier != template.identifier
            or response.prompt_template_version != template.template_version
            or not set(response.evidence_event_ids).issubset(packaged_event_ids)
        ):
            return AIOrchestrationProcessingFailureV1(
                AIProcessingFailureCode.INVALID_PROVIDER_RESPONSE
            )
        return AIOrchestrationCompletedV1(response=response)
