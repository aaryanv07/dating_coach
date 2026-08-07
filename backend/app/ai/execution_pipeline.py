"""Default-off deterministic end-to-end mock AI execution pipeline."""

from typing import Protocol
from uuid import NAMESPACE_URL, UUID, uuid5

from app.ai.coaching_response_codec import StructuredCoachingResponseCodec
from app.ai.coaching_response_contracts import (
    CoachingCapability,
    CoachingResponseParseSuccessV1,
    CoachingResponseValidationFailureV1,
    StructuredCoachingResponseV1,
)
from app.ai.coaching_response_mock import DeterministicCoachingResponseMock
from app.ai.coaching_response_projection import CoachingResponseProjector
from app.ai.coaching_response_validation import (
    StructuredCoachingResponseValidator,
)
from app.ai.coaching_response_versioning import (
    CoachingResponseVersionNegotiator,
)
from app.ai.contracts import (
    AI_REQUEST_SCHEMA_VERSION,
    AIEvidencePackageV1,
    AIResponseStatus,
    AISafetyFailureV1,
)
from app.ai.evidence import AIEvidenceBuilder
from app.ai.execution_contracts import (
    AIExecutionCompletedV1,
    AIExecutionContextV1,
    AIExecutionDiagnosticStatus,
    AIExecutionDiagnosticV1,
    AIExecutionFailureCode,
    AIExecutionFailureV1,
    AIExecutionInterruption,
    AIExecutionRequestV1,
    AIExecutionResultV1,
    AIExecutionStage,
    AIExecutionState,
)
from app.ai.execution_control import (
    AIExecutionAwaiter,
    AIExecutionCancelled,
    AIExecutionControl,
    AIExecutionTimedOut,
    DirectAIExecutionAwaiter,
    StaticAIExecutionControl,
)
from app.ai.provider import MOCK_AI_PROVIDER_IDENTIFIER, AIProvider
from app.ai.provider_contracts import (
    AIProviderExecutionCapability,
    AIProviderSelectionRequestV1,
)
from app.ai.provider_factory import AIProviderCreatedV1, AIProviderFactory
from app.ai.request_builder import AIRequestBuilder
from app.ai.response_parser import AIResponseParseError, AIResponseParser
from app.ai.safety import AIRequestSafetyValidator
from app.domain.conversation_analytics import AnalyticsInputV1, AnalyticsResultV1
from app.domain.conversation_analytics_engine import (
    DeterministicConversationAnalyticsEngine,
)


class AnalyticsEngine(Protocol):
    def analyze(self, payload: AnalyticsInputV1) -> AnalyticsResultV1: ...


class StructuredResponseGenerator(Protocol):
    def generate(
        self,
        *,
        response_id: UUID,
        request_id: UUID,
        evidence_package_id: UUID,
        evidence: AIEvidencePackageV1,
        locale: str = "en",
    ) -> StructuredCoachingResponseV1: ...


class AIConversationExecutionPipeline(Protocol):
    """Provider-independent execution interface for future callers."""

    async def execute(
        self,
        execution_request: AIExecutionRequestV1,
        source: AnalyticsInputV1,
    ) -> AIExecutionResultV1: ...


class AIExecutionCoordinator:
    """Wire every deterministic stage while permitting only the local mock."""

    def __init__(
        self,
        *,
        provider: AIProvider | None,
        provider_factory: AIProviderFactory | None = None,
        execution_enabled: bool = False,
        mock_enabled: bool = False,
        analytics_engine: AnalyticsEngine | None = None,
        evidence_builder: AIEvidenceBuilder | None = None,
        safety_validator: AIRequestSafetyValidator | None = None,
        request_builder: AIRequestBuilder | None = None,
        provider_response_parser: AIResponseParser | None = None,
        response_generator: StructuredResponseGenerator | None = None,
        structured_response_codec: StructuredCoachingResponseCodec | None = None,
        response_validator: StructuredCoachingResponseValidator | None = None,
        version_negotiator: CoachingResponseVersionNegotiator | None = None,
        projector: CoachingResponseProjector | None = None,
        control: AIExecutionControl | None = None,
        awaiter: AIExecutionAwaiter | None = None,
    ) -> None:
        if provider is not None and provider_factory is not None:
            raise ValueError("provider and provider_factory are mutually exclusive")
        self._provider = provider
        self._provider_factory = provider_factory
        self._execution_enabled = execution_enabled
        self._mock_enabled = mock_enabled
        self._analytics_engine = analytics_engine or DeterministicConversationAnalyticsEngine()
        self._evidence_builder = evidence_builder or AIEvidenceBuilder()
        self._safety_validator = safety_validator or AIRequestSafetyValidator()
        self._request_builder = request_builder or AIRequestBuilder()
        self._provider_response_parser = provider_response_parser or AIResponseParser()
        self._response_generator = response_generator or DeterministicCoachingResponseMock()
        self._structured_response_codec = (
            structured_response_codec or StructuredCoachingResponseCodec()
        )
        self._response_validator = response_validator or StructuredCoachingResponseValidator()
        self._version_negotiator = version_negotiator or CoachingResponseVersionNegotiator()
        self._projector = projector or CoachingResponseProjector()
        self._control = control or StaticAIExecutionControl()
        self._awaiter = awaiter or DirectAIExecutionAwaiter()

    async def execute(
        self,
        execution_request: AIExecutionRequestV1,
        source: AnalyticsInputV1,
    ) -> AIExecutionResultV1:
        context = self._context(execution_request)
        diagnostics: list[AIExecutionDiagnosticV1] = []

        def record(
            stage: AIExecutionStage,
            status: AIExecutionDiagnosticStatus,
        ) -> None:
            diagnostics.append(
                AIExecutionDiagnosticV1(
                    sequence=len(diagnostics),
                    stage=stage,
                    status=status,
                )
            )

        def failure(
            stage: AIExecutionStage,
            code: AIExecutionFailureCode,
            *,
            state: AIExecutionState = AIExecutionState.FAILED,
            safety_failures: tuple[AISafetyFailureV1, ...] = (),
            response_failures: tuple[
                CoachingResponseValidationFailureV1,
                ...,
            ] = (),
            status: AIExecutionDiagnosticStatus = (AIExecutionDiagnosticStatus.FAILED),
        ) -> AIExecutionFailureV1:
            record(stage, status)
            return AIExecutionFailureV1(
                context=context,
                state=state,
                code=code,
                diagnostics=tuple(diagnostics),
                safety_failures=safety_failures,
                response_failures=response_failures,
            )

        def interrupted(
            stage: AIExecutionStage,
        ) -> AIExecutionFailureV1 | None:
            interruption = self._control.interruption_before(stage)
            if interruption == AIExecutionInterruption.CANCELLED:
                return failure(
                    stage,
                    AIExecutionFailureCode.CANCELLED,
                    state=AIExecutionState.CANCELLED,
                    status=AIExecutionDiagnosticStatus.CANCELLED,
                )
            if interruption == AIExecutionInterruption.TIMED_OUT:
                return failure(
                    stage,
                    AIExecutionFailureCode.TIMED_OUT,
                    state=AIExecutionState.TIMED_OUT,
                    status=AIExecutionDiagnosticStatus.TIMED_OUT,
                )
            return None

        if result := interrupted(AIExecutionStage.RECEIVED):
            return result
        if not self._execution_enabled:
            return failure(
                AIExecutionStage.RECEIVED,
                AIExecutionFailureCode.EXECUTION_DISABLED,
                state=AIExecutionState.DISABLED,
                status=AIExecutionDiagnosticStatus.DISABLED,
            )
        record(AIExecutionStage.RECEIVED, AIExecutionDiagnosticStatus.PASSED)

        if not self._mock_enabled:
            return failure(
                AIExecutionStage.PROVIDER,
                AIExecutionFailureCode.MOCK_DISABLED,
                state=AIExecutionState.DISABLED,
                status=AIExecutionDiagnosticStatus.DISABLED,
            )

        if result := interrupted(AIExecutionStage.VERSION_NEGOTIATION):
            return result
        negotiation = self._version_negotiator.negotiate(
            execution_request.accepted_response_versions
        )
        if not negotiation.supported:
            return failure(
                AIExecutionStage.VERSION_NEGOTIATION,
                AIExecutionFailureCode.UNSUPPORTED_RESPONSE_VERSION,
                state=AIExecutionState.UNSUPPORTED,
                status=AIExecutionDiagnosticStatus.UNSUPPORTED,
            )
        record(
            AIExecutionStage.VERSION_NEGOTIATION,
            AIExecutionDiagnosticStatus.PASSED,
        )

        if result := interrupted(AIExecutionStage.ANALYTICS):
            return result
        try:
            analytics = self._analytics_engine.analyze(source)
        except Exception:
            return failure(
                AIExecutionStage.ANALYTICS,
                AIExecutionFailureCode.ANALYTICS_FAILURE,
            )
        record(AIExecutionStage.ANALYTICS, AIExecutionDiagnosticStatus.PASSED)

        if result := interrupted(AIExecutionStage.EVIDENCE):
            return result
        evidence = self._evidence_builder.build(
            source.event_sequence,
            analytics,
            execution_request.requirements,
        )
        record(AIExecutionStage.EVIDENCE, AIExecutionDiagnosticStatus.PASSED)

        if result := interrupted(AIExecutionStage.SAFETY):
            return result
        safety_failures = self._safety_validator.validate(
            source,
            evidence,
            execution_request.requirements,
            execution_request.template,
            execution_request.intent,
        )
        if safety_failures:
            return failure(
                AIExecutionStage.SAFETY,
                AIExecutionFailureCode.SAFETY_REJECTED,
                safety_failures=safety_failures,
            )
        record(AIExecutionStage.SAFETY, AIExecutionDiagnosticStatus.PASSED)

        if result := interrupted(AIExecutionStage.REQUEST):
            return result
        provider_request = self._request_builder.build(
            execution_request.request_id,
            execution_request.template,
            execution_request.intent,
            evidence,
        )
        record(AIExecutionStage.REQUEST, AIExecutionDiagnosticStatus.PASSED)

        if result := interrupted(AIExecutionStage.PROVIDER):
            return result
        provider = self._provider
        if self._provider_factory is not None:
            provider_creation = self._provider_factory.create(
                AIProviderSelectionRequestV1(
                    requested_provider_identifier=None,
                    request_schema_version=AI_REQUEST_SCHEMA_VERSION,
                    accepted_response_schema_versions=(
                        execution_request.accepted_response_versions
                    ),
                    required_execution_capabilities=(
                        AIProviderExecutionCapability.FOUNDATION_PLACEHOLDER,
                    ),
                    required_response_capabilities=(
                        CoachingCapability.RESPONSE_SCHEMA,
                        CoachingCapability.EVIDENCE_REFERENCES,
                        CoachingCapability.EXPLANATION_PLACEHOLDERS,
                        CoachingCapability.SAFETY_NOTICES,
                    ),
                    language=execution_request.template.locale,
                )
            )
            if isinstance(provider_creation, AIProviderCreatedV1):
                provider = provider_creation.provider
        if provider is None or provider.identifier != MOCK_AI_PROVIDER_IDENTIFIER:
            return failure(
                AIExecutionStage.PROVIDER,
                AIExecutionFailureCode.PROVIDER_UNAVAILABLE,
            )
        try:
            raw_provider_response = await self._awaiter.run_provider(
                lambda: provider.complete(provider_request)
            )
        except AIExecutionCancelled:
            return failure(
                AIExecutionStage.PROVIDER,
                AIExecutionFailureCode.CANCELLED,
                state=AIExecutionState.CANCELLED,
                status=AIExecutionDiagnosticStatus.CANCELLED,
            )
        except AIExecutionTimedOut:
            return failure(
                AIExecutionStage.PROVIDER,
                AIExecutionFailureCode.TIMED_OUT,
                state=AIExecutionState.TIMED_OUT,
                status=AIExecutionDiagnosticStatus.TIMED_OUT,
            )
        except Exception:
            return failure(
                AIExecutionStage.PROVIDER,
                AIExecutionFailureCode.PROVIDER_FAILURE,
            )
        record(AIExecutionStage.PROVIDER, AIExecutionDiagnosticStatus.PASSED)

        if result := interrupted(AIExecutionStage.PROVIDER_RESPONSE_PARSER):
            return result
        try:
            provider_response = self._provider_response_parser.parse(raw_provider_response)
        except AIResponseParseError:
            return failure(
                AIExecutionStage.PROVIDER_RESPONSE_PARSER,
                AIExecutionFailureCode.PROVIDER_RESPONSE_INVALID,
            )
        packaged_event_ids = {event.event_id for event in evidence.context.events}
        if (
            provider_response.provider_identifier != MOCK_AI_PROVIDER_IDENTIFIER
            or provider_response.status != AIResponseStatus.FOUNDATION_PLACEHOLDER
            or provider_response.request_schema_version != provider_request.schema_version
            or provider_response.prompt_identifier != execution_request.template.identifier
            or provider_response.prompt_template_version
            != execution_request.template.template_version
            or not set(provider_response.evidence_event_ids).issubset(packaged_event_ids)
        ):
            return failure(
                AIExecutionStage.PROVIDER_RESPONSE_PARSER,
                AIExecutionFailureCode.PROVIDER_RESPONSE_INVALID,
            )
        record(
            AIExecutionStage.PROVIDER_RESPONSE_PARSER,
            AIExecutionDiagnosticStatus.PASSED,
        )

        if result := interrupted(AIExecutionStage.STRUCTURED_RESPONSE):
            return result
        structured_response = self._response_generator.generate(
            response_id=context.response_id,
            request_id=execution_request.request_id,
            evidence_package_id=context.evidence_package_id,
            evidence=evidence,
        )
        record(
            AIExecutionStage.STRUCTURED_RESPONSE,
            AIExecutionDiagnosticStatus.PASSED,
        )

        if result := interrupted(AIExecutionStage.STRUCTURED_RESPONSE_PARSER):
            return result
        serialized_response = self._structured_response_codec.serialize(structured_response)
        parsed_response = self._structured_response_codec.parse(serialized_response)
        if not isinstance(parsed_response, CoachingResponseParseSuccessV1):
            return failure(
                AIExecutionStage.STRUCTURED_RESPONSE_PARSER,
                AIExecutionFailureCode.STRUCTURED_RESPONSE_PARSE_FAILURE,
            )
        structured_response = parsed_response.response
        if structured_response.schema_version != negotiation.selected_version:
            return failure(
                AIExecutionStage.STRUCTURED_RESPONSE_PARSER,
                AIExecutionFailureCode.STRUCTURED_RESPONSE_PARSE_FAILURE,
            )
        record(
            AIExecutionStage.STRUCTURED_RESPONSE_PARSER,
            AIExecutionDiagnosticStatus.PASSED,
        )

        if result := interrupted(AIExecutionStage.RESPONSE_VALIDATION):
            return result
        response_failures = self._response_validator.validate(
            structured_response,
            evidence_package_id=context.evidence_package_id,
            evidence=evidence,
        )
        if response_failures:
            return failure(
                AIExecutionStage.RESPONSE_VALIDATION,
                AIExecutionFailureCode.RESPONSE_VALIDATION_FAILURE,
                response_failures=response_failures,
            )
        record(
            AIExecutionStage.RESPONSE_VALIDATION,
            AIExecutionDiagnosticStatus.PASSED,
        )

        if result := interrupted(AIExecutionStage.RENDERER_PROJECTION):
            return result
        projection = self._projector.project(structured_response)
        record(
            AIExecutionStage.RENDERER_PROJECTION,
            AIExecutionDiagnosticStatus.PASSED,
        )
        record(AIExecutionStage.COMPLETED, AIExecutionDiagnosticStatus.PASSED)
        return AIExecutionCompletedV1(
            context=context,
            state=AIExecutionState.COMPLETED,
            projection=projection,
            diagnostics=tuple(diagnostics),
        )

    @staticmethod
    def _context(
        request: AIExecutionRequestV1,
    ) -> AIExecutionContextV1:
        execution_id = uuid5(
            NAMESPACE_URL,
            (
                "convocoach:ai-execution:v1:"
                f"{request.request_id}:"
                f"{request.template.identifier}:"
                f"{request.template.template_version}"
            ),
        )
        return AIExecutionContextV1(
            execution_id=execution_id,
            evidence_package_id=uuid5(
                NAMESPACE_URL,
                f"convocoach:ai-evidence-package:{execution_id}",
            ),
            response_id=uuid5(
                NAMESPACE_URL,
                f"convocoach:ai-structured-response:{execution_id}",
            ),
        )
