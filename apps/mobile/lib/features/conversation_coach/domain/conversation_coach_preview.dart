import 'package:flutter/foundation.dart';

const conversationCoachPreviewSchemaVersion = 'conversation-coach-preview.v1';
const conversationCoachResponseSchemaVersion = 'ai-coaching-response.v1';
const conversationCoachRendererSchemaVersion =
    'ai-coaching-renderer-projection.v1';

enum ConversationCoachSectionStatus { available, unavailable, notice }

enum ConversationCoachErrorCode {
  featureDisabled,
  mockDisabled,
  authenticationRequired,
  authorizationFailed,
  consentRequired,
  externalProcessingConsentRequired,
  conversationUnavailable,
  reviewIncomplete,
  schemaUnsupported,
  incompleteTimeline,
  safetyRejected,
  cancelled,
  timedOut,
  providerUnavailable,
  responseValidationFailed,
  capabilityUnsupported,
  idempotencyRequired,
  idempotencyConflict,
  idempotencyInProgress,
  idempotencyReplayed,
  allowanceExhausted,
  rateLimited,
  budgetExhausted,
  usageUnavailable,
  internalSafeFailure,
}

@immutable
class ConversationCoachSection {
  ConversationCoachSection({
    required this.identifier,
    required this.headingLocalizationKey,
    required this.semanticLabelLocalizationKey,
    required this.status,
    required Iterable<String> itemLocalizationKeys,
    required this.evidenceReferenceCount,
    Iterable<String>? displayItems,
  }) : itemLocalizationKeys = List.unmodifiable(itemLocalizationKeys),
       displayItems = displayItems == null
           ? null
           : List.unmodifiable(displayItems);

  final String identifier;
  final String headingLocalizationKey;
  final String semanticLabelLocalizationKey;
  final ConversationCoachSectionStatus status;
  final List<String> itemLocalizationKeys;
  final int evidenceReferenceCount;
  final List<String>? displayItems;
}

@immutable
class ConversationCoachCalculationVersions {
  const ConversationCoachCalculationVersions({
    required this.analyticsSchemaVersion,
    required this.analyticsCalculationVersion,
    required this.sourceEventSchemaVersion,
  });

  final String analyticsSchemaVersion;
  final String analyticsCalculationVersion;
  final String sourceEventSchemaVersion;
}

@immutable
class ConversationCoachPreview {
  ConversationCoachPreview({
    required this.responseId,
    required this.locale,
    this.calculationVersions,
    required Iterable<ConversationCoachSection> sections,
    required Iterable<String> notices,
    required this.correlationId,
    this.mockExecution = true,
    this.providerLabel = 'Deterministic mock',
    this.inputTokens,
    this.outputTokens,
    this.planCode,
    this.allowanceLimit,
    this.allowanceRemaining,
    this.allowanceResetAt,
  }) : sections = List.unmodifiable(sections),
       notices = List.unmodifiable(notices);

  final String responseId;
  final String locale;
  final ConversationCoachCalculationVersions? calculationVersions;
  final List<ConversationCoachSection> sections;
  final List<String> notices;
  final String correlationId;
  final bool mockExecution;
  final String providerLabel;
  final int? inputTokens;
  final int? outputTokens;
  final String? planCode;
  final int? allowanceLimit;
  final int? allowanceRemaining;
  final DateTime? allowanceResetAt;
}

@immutable
class ConversationCoachFailure {
  const ConversationCoachFailure({
    required this.code,
    required this.localizationKey,
    required this.retryable,
    required this.retryGuidanceLocalizationKey,
    required this.correlationId,
  });

  final ConversationCoachErrorCode code;
  final String localizationKey;
  final bool retryable;
  final String? retryGuidanceLocalizationKey;
  final String correlationId;
}

sealed class ConversationCoachRepositoryResult {
  const ConversationCoachRepositoryResult();
}

class ConversationCoachRepositorySuccess
    extends ConversationCoachRepositoryResult {
  const ConversationCoachRepositorySuccess(this.preview);

  final ConversationCoachPreview preview;
}

class ConversationCoachRepositoryFailure
    extends ConversationCoachRepositoryResult {
  const ConversationCoachRepositoryFailure(this.failure);

  final ConversationCoachFailure failure;
}
