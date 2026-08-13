"""Secure Conversation Coach service for mock and approved external AI execution."""

import asyncio
import hashlib
import logging
from dataclasses import dataclass
from typing import Literal, cast
from uuid import NAMESPACE_URL, UUID, uuid4, uuid5

from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.coaching_profile import UserCoachingProfileV1, build_user_coaching_profile
from app.ai.contracts import (
    AIPromptTemplateV1,
    AIRequestIntentV1,
    AIRequestPurpose,
    AIRequestRequirementsV1,
)
from app.ai.execution_contracts import (
    AIExecutionCompletedV1,
    AIExecutionFailureCode,
    AIExecutionFailureV1,
    AIExecutionRequestV1,
)
from app.ai.execution_pipeline import (
    AIConversationExecutionPipeline,
    AIExecutionCoordinator,
)
from app.ai.external_safety import EXTERNAL_AI_CONSENT_TYPE, EXTERNAL_AI_POLICY_VERSION
from app.ai.openai_terra import (
    OpenAITerraProvider,
    TerraConversationCoachProvider,
    TerraProviderFailure,
    TerraProviderFailureCode,
    build_terra_context,
    privacy_safe_safety_identifier,
)
from app.ai.openrouter import (
    OPENROUTER_PROVIDER_IDENTIFIER,
    OpenRouterConversationCoachProvider,
    OpenRouterProviderFailure,
    OpenRouterProviderFailureCode,
    OpenRouterTieredProvider,
    build_openrouter_context,
    privacy_safe_openrouter_user_identifier,
)
from app.ai.provider_factory import AIProviderFactory
from app.ai.zai_glm import (
    ZAI_GLM_PROVIDER_IDENTIFIER,
    GLMConversationCoachProvider,
    GLMProviderFailure,
    GLMProviderFailureCode,
    ZaiGLMProvider,
    build_glm_context,
    privacy_safe_user_identifier,
)
from app.core.config import OPENAI_TERRA_MODEL, ZAI_GLM_MODEL, Settings
from app.core.observability import OPERATIONAL_LOGGER_NAME
from app.db.models import CommunicationProfile, Conversation
from app.domain.conversation_analytics import (
    AnalyticsInputV1,
    AnalyticsReviewStatus,
)
from app.domain.conversation_events import (
    ConfirmedConversationEvent,
    ConfirmedConversationEventRelationship,
    ConfirmedConversationEventSequence,
    ConversationEventRelationshipType,
    ConversationEventSpeaker,
    ConversationEventType,
)
from app.repositories.conversations import ConversationRepository
from app.repositories.users import ConsentRepository
from app.schemas.conversation_coach import (
    CoachLiveAllowanceV1,
    CoachLiveObservationV1,
    CoachLiveProvenanceV1,
    CoachLiveReplyDraftV1,
    CoachLiveSuccessV2,
    CoachLiveUsageV1,
    CoachPreviewCalculationVersionsV1,
    CoachPreviewErrorCode,
    CoachPreviewProvenanceV1,
    CoachPreviewSectionTransportV1,
    CoachPreviewSuccessV1,
)
from app.subscriptions.contracts import SubscriptionPlanCode
from app.subscriptions.runtime import (
    AIUsageRepository,
    UsageReservation,
    UsageRuntimeFailure,
    UsageRuntimeFailureCode,
    usage_policy_from_settings,
)

_REQUIRED_METRICS = ("messages.total", "structure.unknown_events")
_ACCEPTED_RESPONSE_VERSIONS = ("ai-coaching-response.v1",)
_NOTICE_KEYS = (
    "coaching.foundation.mock_only",
    "coaching.foundation.no_coaching_generated",
)
_EXTERNAL_PROVIDER_MODES = frozenset({"openai_terra", "zai_glm", "openrouter_tiered"})


@dataclass(frozen=True, slots=True)
class CoachPreviewServiceFailure(Exception):
    """Internal content-free signal mapped to the public failure contract."""

    code: CoachPreviewErrorCode
    http_status: int
    retryable: bool = False


class ConversationCoachPreviewService:
    """Authorizes, validates, executes, and projects one non-persistent preview."""

    def __init__(
        self,
        session: AsyncSession,
        settings: Settings,
        *,
        pipeline: AIConversationExecutionPipeline | None = None,
        terra_provider: TerraConversationCoachProvider | None = None,
        glm_provider: GLMConversationCoachProvider | None = None,
        openrouter_provider: OpenRouterConversationCoachProvider | None = None,
        usage_repository: AIUsageRepository | None = None,
    ) -> None:
        self._session = session
        self._settings = settings
        self._pipeline = pipeline
        self._terra_provider = terra_provider
        self._glm_provider = glm_provider
        self._openrouter_provider = openrouter_provider
        self._usage_repository = usage_repository

    async def execute(
        self,
        *,
        owner_id: UUID,
        conversation_id: UUID,
        correlation_id: UUID,
        idempotency_key: str | None = None,
    ) -> CoachPreviewSuccessV1 | CoachLiveSuccessV2:
        repository = ConversationRepository(self._session)
        conversation = await repository.get_owned(owner_id, conversation_id)
        if conversation is None:
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.CONVERSATION_UNAVAILABLE,
                404,
            )

        has_consent = await ConsentRepository(self._session).has_active(
            owner_id,
            "save_conversation_history",
        )
        if not has_consent:
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.CONSENT_REQUIRED,
                403,
            )

        if conversation.status != "confirmed" or not conversation.events:
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.REVIEW_INCOMPLETE,
                409,
            )
        if any(
            event.requires_review or event.event_type == ConversationEventType.UNKNOWN.value
            for event in conversation.events
            if event.deleted_at is None
        ):
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.REVIEW_INCOMPLETE,
                409,
            )
        if [event.position for event in conversation.events] != list(
            range(len(conversation.events))
        ):
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.INCOMPLETE_TIMELINE,
                422,
            )

        if not self._settings.ai_coaching_enabled:
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.FEATURE_DISABLED,
                503,
            )
        if (
            self._settings.ai_provider_mode == "mock"
            and not self._settings.ai_mock_execution_enabled
        ):
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.MOCK_DISABLED,
                503,
            )

        if self._settings.ai_provider_mode in _EXTERNAL_PROVIDER_MODES:
            has_external_processing_consent = await ConsentRepository(self._session).has_active(
                owner_id,
                EXTERNAL_AI_CONSENT_TYPE,
                policy_version=EXTERNAL_AI_POLICY_VERSION,
            )
            if not has_external_processing_consent:
                raise CoachPreviewServiceFailure(
                    CoachPreviewErrorCode.EXTERNAL_PROCESSING_CONSENT_REQUIRED,
                    403,
                )

        try:
            sequence = await self._canonical_sequence(repository, conversation)
        except ValueError as error:
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.SCHEMA_UNSUPPORTED,
                422,
            ) from error

        stored_profile = await self._session.get(CommunicationProfile, owner_id)
        user_profile = build_user_coaching_profile(stored_profile)

        if self._settings.ai_provider_mode in _EXTERNAL_PROVIDER_MODES:
            if not self._settings.ai_usage_enforcement_enabled:
                raise CoachPreviewServiceFailure(
                    CoachPreviewErrorCode.USAGE_UNAVAILABLE,
                    503,
                )
            if idempotency_key is None:
                raise CoachPreviewServiceFailure(
                    CoachPreviewErrorCode.IDEMPOTENCY_REQUIRED,
                    422,
                )
            usage_repository = self._usage_repository or AIUsageRepository(
                self._session,
                usage_policy_from_settings(self._settings),
            )
            fingerprint = hashlib.sha256(
                (
                    f"conversation-coach.v2:{conversation.id}:"
                    f"{conversation.updated_at.isoformat()}:"
                    f"{stored_profile.updated_at.isoformat() if stored_profile else 'no-profile'}:"
                    + ",".join(str(event.id) for event in sequence.events)
                ).encode()
            ).hexdigest()
            model_identifier: str | None
            model_identifiers_by_plan: dict[SubscriptionPlanCode, str] | None
            if self._settings.ai_provider_mode == "openrouter_tiered":
                model_identifier = None
                model_identifiers_by_plan = {
                    SubscriptionPlanCode.WELCOME: self._settings.openrouter_free_model,
                    SubscriptionPlanCode.FREE: self._settings.openrouter_free_model,
                    SubscriptionPlanCode.PLUS: self._settings.openrouter_paid_model,
                }
            else:
                model_identifier = (
                    ZAI_GLM_MODEL
                    if self._settings.ai_provider_mode == "zai_glm"
                    else OPENAI_TERRA_MODEL
                )
                model_identifiers_by_plan = None
            try:
                reservation = await usage_repository.reserve_conversation_analysis(
                    user_id=owner_id,
                    conversation_id=conversation.id,
                    idempotency_key=idempotency_key,
                    request_fingerprint=fingerprint,
                    model_identifier=model_identifier,
                    model_identifiers_by_plan=model_identifiers_by_plan,
                    correlation_id=correlation_id,
                )
            except UsageRuntimeFailure as error:
                raise self._map_usage_failure(error) from error
            if self._settings.ai_provider_mode == "zai_glm":
                return await self._execute_glm(
                    sequence=sequence,
                    owner_id=owner_id,
                    correlation_id=correlation_id,
                    usage_repository=usage_repository,
                    reservation=reservation,
                    user_profile=user_profile,
                )
            if self._settings.ai_provider_mode == "openrouter_tiered":
                return await self._execute_openrouter(
                    sequence=sequence,
                    owner_id=owner_id,
                    correlation_id=correlation_id,
                    usage_repository=usage_repository,
                    reservation=reservation,
                    user_profile=user_profile,
                )
            return await self._execute_terra(
                sequence=sequence,
                owner_id=owner_id,
                correlation_id=correlation_id,
                usage_repository=usage_repository,
                reservation=reservation,
                user_profile=user_profile,
            )

        request_id = uuid5(
            NAMESPACE_URL,
            f"convocoach:conversation-coach-preview:v1:{owner_id}:{conversation_id}",
        )
        execution_request = AIExecutionRequestV1(
            request_id=request_id,
            requirements=AIRequestRequirementsV1(required_metric_identifiers=_REQUIRED_METRICS),
            template=AIPromptTemplateV1(
                identifier="foundation-validation",
                template_version="1.0.0",
                locale="en",
                input_slots=("evidence",),
            ),
            intent=AIRequestIntentV1(purpose=AIRequestPurpose.FOUNDATION_VALIDATION),
            accepted_response_versions=_ACCEPTED_RESPONSE_VERSIONS,
        )
        pipeline = self._pipeline or AIExecutionCoordinator(
            provider=None,
            provider_factory=AIProviderFactory.default(
                ai_coaching_enabled=self._settings.ai_coaching_enabled,
                ai_mock_execution_enabled=self._settings.ai_mock_execution_enabled,
            ),
            execution_enabled=self._settings.ai_coaching_enabled,
            mock_enabled=self._settings.ai_mock_execution_enabled,
        )
        result = await pipeline.execute(
            execution_request,
            AnalyticsInputV1(
                event_sequence=sequence,
                review_status=AnalyticsReviewStatus.CONFIRMED,
                timeline_gaps=(),
                is_partial=False,
            ),
        )
        if isinstance(result, AIExecutionFailureV1):
            raise self._map_execution_failure(result.code)
        if not isinstance(result, AIExecutionCompletedV1):
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.INTERNAL_SAFE_FAILURE,
                500,
                retryable=True,
            )
        return CoachPreviewSuccessV1(
            response_id=result.projection.response_id,
            locale=result.projection.locale,
            calculation_versions=CoachPreviewCalculationVersionsV1(),
            sections=tuple(
                CoachPreviewSectionTransportV1(
                    identifier=section.identifier,
                    heading_localization_key=section.heading_localization_key,
                    semantic_label_localization_key=(section.semantic_label_localization_key),
                    status=section.status.value,
                    item_localization_keys=section.item_localization_keys,
                    evidence_reference_count=section.evidence_reference_count,
                )
                for section in result.projection.sections
            ),
            notices=_NOTICE_KEYS,
            provenance=CoachPreviewProvenanceV1(),
            correlation_id=correlation_id,
        )

    async def _execute_terra(
        self,
        *,
        sequence: ConfirmedConversationEventSequence,
        owner_id: UUID,
        correlation_id: UUID,
        usage_repository: AIUsageRepository,
        reservation: UsageReservation,
        user_profile: UserCoachingProfileV1 | None,
    ) -> CoachLiveSuccessV2:
        try:
            context = build_terra_context(sequence.events, user_profile)
            provider = self._terra_provider or OpenAITerraProvider(
                api_key=self._settings.openai_api_key,
                timeout_seconds=self._settings.openai_request_timeout_seconds,
            )
            async with asyncio.timeout(self._settings.openai_request_timeout_seconds):
                result = await provider.coach(
                    context,
                    safety_identifier=privacy_safe_safety_identifier(
                        owner_id,
                        self._settings.openai_safety_identifier_secret,
                    ),
                )
        except TimeoutError as error:
            await usage_repository.release(
                user_id=owner_id,
                record_id=reservation.record_id,
            )
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.TIMED_OUT,
                504,
                retryable=True,
            ) from error
        except TerraProviderFailure as error:
            await usage_repository.release(
                user_id=owner_id,
                record_id=reservation.record_id,
            )
            mapping = {
                TerraProviderFailureCode.INVALID_CONTEXT: (
                    CoachPreviewErrorCode.REVIEW_INCOMPLETE,
                    409,
                    False,
                ),
                TerraProviderFailureCode.PROVIDER_UNAVAILABLE: (
                    CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
                    503,
                    True,
                ),
                TerraProviderFailureCode.PROVIDER_REFUSED: (
                    CoachPreviewErrorCode.SAFETY_REJECTED,
                    422,
                    False,
                ),
                TerraProviderFailureCode.RESPONSE_INVALID: (
                    CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                    502,
                    True,
                ),
            }
            code, http_status, retryable = mapping[error.code]
            raise CoachPreviewServiceFailure(
                code,
                http_status,
                retryable=retryable,
            ) from error

        try:
            allowance = await usage_repository.complete(
                user_id=owner_id,
                record_id=reservation.record_id,
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            )
        except UsageRuntimeFailure as error:
            raise self._map_usage_failure(error) from error
        request_cost_microusd = usage_repository.estimated_cost_microusd(
            input_tokens=result.usage.input_tokens,
            output_tokens=result.usage.output_tokens,
        )
        await self._emit_budget_alerts(
            usage_repository=usage_repository,
            owner_id=owner_id,
            correlation_id=correlation_id,
            request_cost_microusd=request_cost_microusd,
        )

        provider_limitations: list[str] = list(result.response.limitations)
        if context.earlier_messages_omitted:
            provider_limitations.append(
                "Earlier reviewed messages were omitted by the privacy and cost context limit."
            )
        if context.message_text_truncated:
            provider_limitations.append(
                "One or more unusually long messages were shortened before processing."
            )
        return CoachLiveSuccessV2(
            response_id=uuid4(),
            summary=result.response.summary,
            observations=tuple(
                CoachLiveObservationV1(
                    heading=item.heading,
                    observation=item.observation,
                    uncertainty=item.uncertainty,
                    alternative_interpretations=item.alternative_interpretations,
                    evidence_event_ids=item.evidence_event_ids,
                )
                for item in result.response.observations
            ),
            next_steps=result.response.next_steps,
            reply_drafts=tuple(
                CoachLiveReplyDraftV1(
                    text=draft.text,
                    tone=draft.tone,
                    rationale=draft.rationale,
                )
                for draft in result.response.reply_drafts
            ),
            safety_notices=result.response.safety_notices,
            limitations=tuple(provider_limitations),
            provenance=CoachLiveProvenanceV1(),
            usage=CoachLiveUsageV1(
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            ),
            allowance=CoachLiveAllowanceV1(
                plan_code=allowance.plan_code.value,
                plan_status=cast(Literal["active", "grace"], allowance.plan_status),
                limit=allowance.limit,
                consumed=allowance.consumed,
                reserved=allowance.reserved,
                remaining=allowance.remaining,
                reset_at=allowance.reset_at,
            ),
            correlation_id=correlation_id,
        )

    async def _execute_glm(
        self,
        *,
        sequence: ConfirmedConversationEventSequence,
        owner_id: UUID,
        correlation_id: UUID,
        usage_repository: AIUsageRepository,
        reservation: UsageReservation,
        user_profile: UserCoachingProfileV1 | None,
    ) -> CoachLiveSuccessV2:
        try:
            context = build_glm_context(sequence.events, user_profile)
            provider = self._glm_provider or ZaiGLMProvider(
                api_key=self._settings.zai_api_key,
                timeout_seconds=self._settings.zai_request_timeout_seconds,
            )
            async with asyncio.timeout(self._settings.zai_request_timeout_seconds):
                result = await provider.coach(
                    context,
                    user_identifier=privacy_safe_user_identifier(
                        owner_id,
                        self._settings.zai_user_identifier_secret,
                    ),
                )
        except TimeoutError as error:
            await usage_repository.release(user_id=owner_id, record_id=reservation.record_id)
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.TIMED_OUT,
                504,
                retryable=True,
            ) from error
        except GLMProviderFailure as error:
            await usage_repository.release(user_id=owner_id, record_id=reservation.record_id)
            mapping = {
                GLMProviderFailureCode.INVALID_CONTEXT: (
                    CoachPreviewErrorCode.REVIEW_INCOMPLETE,
                    409,
                    False,
                ),
                GLMProviderFailureCode.SAFETY_BLOCKED: (
                    CoachPreviewErrorCode.SAFETY_REJECTED,
                    422,
                    False,
                ),
                GLMProviderFailureCode.PROVIDER_UNAVAILABLE: (
                    CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
                    503,
                    True,
                ),
                GLMProviderFailureCode.PROVIDER_REFUSED: (
                    CoachPreviewErrorCode.SAFETY_REJECTED,
                    422,
                    False,
                ),
                GLMProviderFailureCode.RESPONSE_INVALID: (
                    CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                    502,
                    True,
                ),
            }
            code, http_status, retryable = mapping[error.code]
            raise CoachPreviewServiceFailure(code, http_status, retryable=retryable) from error

        try:
            allowance = await usage_repository.complete(
                user_id=owner_id,
                record_id=reservation.record_id,
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            )
        except UsageRuntimeFailure as error:
            raise self._map_usage_failure(error) from error
        request_cost_microusd = usage_repository.estimated_cost_microusd(
            input_tokens=result.usage.input_tokens,
            output_tokens=result.usage.output_tokens,
        )
        await self._emit_budget_alerts(
            usage_repository=usage_repository,
            owner_id=owner_id,
            correlation_id=correlation_id,
            request_cost_microusd=request_cost_microusd,
        )

        provider_limitations: list[str] = list(result.response.limitations)
        if context.earlier_messages_omitted:
            provider_limitations.append(
                "Earlier reviewed messages were omitted by the privacy and cost context limit."
            )
        if context.message_text_truncated:
            provider_limitations.append(
                "One or more unusually long messages were shortened before processing."
            )
        return CoachLiveSuccessV2(
            response_schema_version="glm-coach-output.v1",
            response_id=uuid4(),
            summary=result.response.summary,
            observations=tuple(
                CoachLiveObservationV1(
                    heading=item.heading,
                    observation=item.observation,
                    uncertainty=item.uncertainty,
                    alternative_interpretations=item.alternative_interpretations,
                    evidence_event_ids=item.evidence_event_ids,
                )
                for item in result.response.observations
            ),
            next_steps=result.response.next_steps,
            reply_drafts=tuple(
                CoachLiveReplyDraftV1(
                    text=draft.text,
                    tone=draft.tone,
                    rationale=draft.rationale,
                )
                for draft in result.response.reply_drafts
            ),
            safety_notices=result.response.safety_notices,
            limitations=tuple(provider_limitations),
            provenance=CoachLiveProvenanceV1(
                provider_identifier=ZAI_GLM_PROVIDER_IDENTIFIER,
                model=ZAI_GLM_MODEL,
            ),
            usage=CoachLiveUsageV1(
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            ),
            allowance=CoachLiveAllowanceV1(
                plan_code=allowance.plan_code.value,
                plan_status=cast(Literal["active", "grace"], allowance.plan_status),
                limit=allowance.limit,
                consumed=allowance.consumed,
                reserved=allowance.reserved,
                remaining=allowance.remaining,
                reset_at=allowance.reset_at,
            ),
            correlation_id=correlation_id,
        )

    async def _execute_openrouter(
        self,
        *,
        sequence: ConfirmedConversationEventSequence,
        owner_id: UUID,
        correlation_id: UUID,
        usage_repository: AIUsageRepository,
        reservation: UsageReservation,
        user_profile: UserCoachingProfileV1 | None,
    ) -> CoachLiveSuccessV2:
        model = reservation.model_identifier
        configured_models = {
            self._settings.openrouter_free_model,
            self._settings.openrouter_paid_model,
        }
        if model not in configured_models:
            await usage_repository.release(user_id=owner_id, record_id=reservation.record_id)
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.USAGE_UNAVAILABLE,
                503,
            )
        configured_effort = (
            self._settings.openrouter_paid_reasoning_effort
            if model == self._settings.openrouter_paid_model
            else self._settings.openrouter_free_reasoning_effort
        )
        reasoning_effort = None if configured_effort == "none" else configured_effort
        try:
            context = build_openrouter_context(sequence.events, user_profile)
            provider = self._openrouter_provider or OpenRouterTieredProvider(
                api_key=self._settings.openrouter_api_key,
                timeout_seconds=self._settings.openrouter_request_timeout_seconds,
            )
            async with asyncio.timeout(self._settings.openrouter_request_timeout_seconds):
                result = await provider.coach(
                    context,
                    model=model,
                    user_identifier=privacy_safe_openrouter_user_identifier(
                        owner_id,
                        self._settings.openrouter_user_identifier_secret,
                    ),
                    reasoning_effort=reasoning_effort,
                )
        except TimeoutError as error:
            await usage_repository.release(user_id=owner_id, record_id=reservation.record_id)
            raise CoachPreviewServiceFailure(
                CoachPreviewErrorCode.TIMED_OUT,
                504,
                retryable=True,
            ) from error
        except OpenRouterProviderFailure as error:
            await usage_repository.release(user_id=owner_id, record_id=reservation.record_id)
            mapping = {
                OpenRouterProviderFailureCode.INVALID_CONTEXT: (
                    CoachPreviewErrorCode.REVIEW_INCOMPLETE,
                    409,
                    False,
                ),
                OpenRouterProviderFailureCode.SAFETY_BLOCKED: (
                    CoachPreviewErrorCode.SAFETY_REJECTED,
                    422,
                    False,
                ),
                OpenRouterProviderFailureCode.PROVIDER_UNAVAILABLE: (
                    CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
                    503,
                    True,
                ),
                OpenRouterProviderFailureCode.PROVIDER_REFUSED: (
                    CoachPreviewErrorCode.SAFETY_REJECTED,
                    422,
                    False,
                ),
                OpenRouterProviderFailureCode.RESPONSE_INVALID: (
                    CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                    502,
                    True,
                ),
            }
            code, http_status, retryable = mapping[error.code]
            raise CoachPreviewServiceFailure(code, http_status, retryable=retryable) from error

        try:
            allowance = await usage_repository.complete(
                user_id=owner_id,
                record_id=reservation.record_id,
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            )
        except UsageRuntimeFailure as error:
            raise self._map_usage_failure(error) from error
        request_cost_microusd = usage_repository.estimated_cost_microusd(
            input_tokens=result.usage.input_tokens,
            output_tokens=result.usage.output_tokens,
            model_identifier=model,
        )
        await self._emit_budget_alerts(
            usage_repository=usage_repository,
            owner_id=owner_id,
            correlation_id=correlation_id,
            request_cost_microusd=request_cost_microusd,
        )

        provider_limitations: list[str] = list(result.response.limitations)
        if context.earlier_messages_omitted:
            provider_limitations.append(
                "Earlier reviewed messages were omitted by the privacy and cost context limit."
            )
        if context.message_text_truncated:
            provider_limitations.append(
                "One or more unusually long messages were shortened before processing."
            )
        return CoachLiveSuccessV2(
            response_schema_version="openrouter-coach-output.v1",
            response_id=uuid4(),
            summary=result.response.summary,
            observations=tuple(
                CoachLiveObservationV1(
                    heading=item.heading,
                    observation=item.observation,
                    uncertainty=item.uncertainty,
                    alternative_interpretations=item.alternative_interpretations,
                    evidence_event_ids=item.evidence_event_ids,
                )
                for item in result.response.observations
            ),
            next_steps=result.response.next_steps,
            reply_drafts=tuple(
                CoachLiveReplyDraftV1(
                    text=draft.text,
                    tone=draft.tone,
                    rationale=draft.rationale,
                )
                for draft in result.response.reply_drafts
            ),
            safety_notices=result.response.safety_notices,
            limitations=tuple(provider_limitations),
            provenance=CoachLiveProvenanceV1(
                provider_identifier=OPENROUTER_PROVIDER_IDENTIFIER,
                model=model,
            ),
            usage=CoachLiveUsageV1(
                input_tokens=result.usage.input_tokens,
                output_tokens=result.usage.output_tokens,
                total_tokens=result.usage.total_tokens,
            ),
            allowance=CoachLiveAllowanceV1(
                plan_code=allowance.plan_code.value,
                plan_status=cast(Literal["active", "grace"], allowance.plan_status),
                limit=allowance.limit,
                consumed=allowance.consumed,
                reserved=allowance.reserved,
                remaining=allowance.remaining,
                reset_at=allowance.reset_at,
            ),
            correlation_id=correlation_id,
        )

    async def _emit_budget_alerts(
        self,
        *,
        usage_repository: AIUsageRepository,
        owner_id: UUID,
        correlation_id: UUID,
        request_cost_microusd: int,
    ) -> None:
        snapshot = await usage_repository.budget_snapshot(user_id=owner_id)
        threshold = self._settings.ai_budget_alert_percent
        logger = logging.getLogger(OPERATIONAL_LOGGER_NAME)
        values = (
            (
                "ai_user_budget_threshold_reached",
                snapshot.user_cost_microusd,
                snapshot.user_budget_microusd,
            ),
            (
                "ai_global_budget_threshold_reached",
                snapshot.global_cost_microusd,
                snapshot.global_budget_microusd,
            ),
        )
        for event, current, ceiling in values:
            previous = max(current - request_cost_microusd, 0)
            if current * 100 >= ceiling * threshold and previous * 100 < ceiling * threshold:
                logger.warning(
                    "",
                    extra={
                        "event": event,
                        "correlation_id": str(correlation_id),
                    },
                )

    async def _canonical_sequence(
        self,
        repository: ConversationRepository,
        conversation: Conversation,
    ) -> ConfirmedConversationEventSequence:
        relationships = await repository.list_event_relationships(conversation.id)
        return ConfirmedConversationEventSequence(
            schema_version="conversation-events.v1",
            events=tuple(
                ConfirmedConversationEvent(
                    id=event.id,
                    position=event.position,
                    event_type=ConversationEventType(event.event_type),
                    speaker=ConversationEventSpeaker(event.speaker),
                    text=event.text,
                    timestamp=event.timestamp,
                    timestamp_is_estimated=event.timestamp_is_estimated,
                    raw_timestamp_text=event.raw_timestamp_text,
                    source_image_index=event.source_image_index,
                    source_region_id=event.source_region_id,
                    ocr_confidence=event.ocr_confidence,
                    classification_confidence=event.classification_confidence,
                    speaker_confidence=event.speaker_confidence,
                    timestamp_confidence=event.timestamp_confidence,
                    relationship_confidence=event.relationship_confidence,
                    requires_review=event.requires_review,
                    metadata=event.metadata_json,
                    deleted_at=event.deleted_at,
                )
                for event in conversation.events
            ),
            relationships=tuple(
                ConfirmedConversationEventRelationship(
                    id=relationship.id,
                    source_event_id=relationship.source_event_id,
                    target_event_id=relationship.target_event_id,
                    relationship_type=ConversationEventRelationshipType(
                        relationship.relationship_type
                    ),
                    confidence=relationship.confidence,
                    metadata=relationship.metadata_json,
                )
                for relationship in relationships
            ),
        )

    @staticmethod
    def _map_execution_failure(
        code: AIExecutionFailureCode,
    ) -> CoachPreviewServiceFailure:
        mapping = {
            AIExecutionFailureCode.EXECUTION_DISABLED: (
                CoachPreviewErrorCode.FEATURE_DISABLED,
                503,
                False,
            ),
            AIExecutionFailureCode.MOCK_DISABLED: (
                CoachPreviewErrorCode.MOCK_DISABLED,
                503,
                False,
            ),
            AIExecutionFailureCode.CANCELLED: (
                CoachPreviewErrorCode.CANCELLED,
                409,
                True,
            ),
            AIExecutionFailureCode.TIMED_OUT: (
                CoachPreviewErrorCode.TIMED_OUT,
                504,
                True,
            ),
            AIExecutionFailureCode.UNSUPPORTED_RESPONSE_VERSION: (
                CoachPreviewErrorCode.CAPABILITY_UNSUPPORTED,
                422,
                False,
            ),
            AIExecutionFailureCode.SAFETY_REJECTED: (
                CoachPreviewErrorCode.SAFETY_REJECTED,
                422,
                False,
            ),
            AIExecutionFailureCode.PROVIDER_UNAVAILABLE: (
                CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
                503,
                True,
            ),
            AIExecutionFailureCode.PROVIDER_FAILURE: (
                CoachPreviewErrorCode.PROVIDER_UNAVAILABLE,
                503,
                True,
            ),
            AIExecutionFailureCode.PROVIDER_RESPONSE_INVALID: (
                CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                502,
                True,
            ),
            AIExecutionFailureCode.STRUCTURED_RESPONSE_PARSE_FAILURE: (
                CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                502,
                True,
            ),
            AIExecutionFailureCode.RESPONSE_VALIDATION_FAILURE: (
                CoachPreviewErrorCode.RESPONSE_VALIDATION_FAILED,
                502,
                True,
            ),
            AIExecutionFailureCode.ANALYTICS_FAILURE: (
                CoachPreviewErrorCode.INTERNAL_SAFE_FAILURE,
                500,
                True,
            ),
        }
        error_code, http_status, retryable = mapping[code]
        return CoachPreviewServiceFailure(
            error_code,
            http_status,
            retryable=retryable,
        )

    @staticmethod
    def _map_usage_failure(error: UsageRuntimeFailure) -> CoachPreviewServiceFailure:
        mapping = {
            UsageRuntimeFailureCode.IDEMPOTENCY_CONFLICT: (
                CoachPreviewErrorCode.IDEMPOTENCY_CONFLICT,
                409,
                False,
            ),
            UsageRuntimeFailureCode.IDEMPOTENCY_IN_PROGRESS: (
                CoachPreviewErrorCode.IDEMPOTENCY_IN_PROGRESS,
                409,
                True,
            ),
            UsageRuntimeFailureCode.IDEMPOTENCY_REPLAYED: (
                CoachPreviewErrorCode.IDEMPOTENCY_REPLAYED,
                409,
                False,
            ),
            UsageRuntimeFailureCode.ALLOWANCE_EXHAUSTED: (
                CoachPreviewErrorCode.ALLOWANCE_EXHAUSTED,
                429,
                False,
            ),
            UsageRuntimeFailureCode.RATE_LIMITED: (
                CoachPreviewErrorCode.RATE_LIMITED,
                429,
                error.retryable,
            ),
            UsageRuntimeFailureCode.BUDGET_EXHAUSTED: (
                CoachPreviewErrorCode.BUDGET_EXHAUSTED,
                503,
                False,
            ),
            UsageRuntimeFailureCode.USAGE_UNAVAILABLE: (
                CoachPreviewErrorCode.USAGE_UNAVAILABLE,
                503,
                True,
            ),
        }
        code, status, retryable = mapping[error.code]
        return CoachPreviewServiceFailure(code, status, retryable=retryable)
