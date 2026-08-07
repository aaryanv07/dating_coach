import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:flutter/foundation.dart';

sealed class ConversationCoachState {
  const ConversationCoachState();
}

class ConversationCoachUnavailable extends ConversationCoachState {
  const ConversationCoachUnavailable();
}

class ConversationCoachFeatureDisabled extends ConversationCoachState {
  const ConversationCoachFeatureDisabled();
}

class ConversationCoachMockDisabled extends ConversationCoachState {
  const ConversationCoachMockDisabled();
}

class ConversationCoachLoading extends ConversationCoachState {
  const ConversationCoachLoading();
}

class ConversationCoachReady extends ConversationCoachState {
  const ConversationCoachReady(this.preview);

  final ConversationCoachPreviewViewModel preview;
}

class ConversationCoachEmpty extends ConversationCoachState {
  const ConversationCoachEmpty();
}

class ConversationCoachReviewIncomplete extends ConversationCoachState {
  const ConversationCoachReviewIncomplete();
}

class ConversationCoachUnsupported extends ConversationCoachState {
  const ConversationCoachUnsupported();
}

class ConversationCoachConsentRequired extends ConversationCoachState {
  const ConversationCoachConsentRequired();
}

class ConversationCoachExternalConsentRequired extends ConversationCoachState {
  const ConversationCoachExternalConsentRequired();
}

class ConversationCoachGrantingConsent extends ConversationCoachState {
  const ConversationCoachGrantingConsent();
}

class ConversationCoachTimedOut extends ConversationCoachState {
  const ConversationCoachTimedOut();
}

class ConversationCoachCancelled extends ConversationCoachState {
  const ConversationCoachCancelled();
}

class ConversationCoachExecutionFailed extends ConversationCoachState {
  const ConversationCoachExecutionFailed();
}

class ConversationCoachNetworkUnavailable extends ConversationCoachState {
  const ConversationCoachNetworkUnavailable();
}

class ConversationCoachSafeFailure extends ConversationCoachState {
  const ConversationCoachSafeFailure();
}

class ConversationCoachAllowanceExhausted extends ConversationCoachState {
  const ConversationCoachAllowanceExhausted();
}

class ConversationCoachRateLimited extends ConversationCoachState {
  const ConversationCoachRateLimited();
}

class ConversationCoachBudgetUnavailable extends ConversationCoachState {
  const ConversationCoachBudgetUnavailable();
}

@immutable
class ConversationCoachSectionViewModel {
  ConversationCoachSectionViewModel({
    required this.identifier,
    required this.heading,
    required this.semanticLabel,
    required this.status,
    required Iterable<String> items,
    required this.evidenceReferenceCount,
  }) : items = List.unmodifiable(items);

  final String identifier;
  final String heading;
  final String semanticLabel;
  final ConversationCoachSectionStatus status;
  final List<String> items;
  final int evidenceReferenceCount;
}

@immutable
class ConversationCoachPreviewViewModel {
  ConversationCoachPreviewViewModel({
    required Iterable<ConversationCoachSectionViewModel> sections,
    required Iterable<String> notices,
    required this.responseId,
    required this.correlationId,
    required this.mockExecution,
    required this.providerLabel,
    this.analyticsSchemaVersion,
    this.analyticsCalculationVersion,
    this.sourceEventSchemaVersion,
    this.inputTokens,
    this.outputTokens,
    this.planCode,
    this.allowanceLimit,
    this.allowanceRemaining,
    this.allowanceResetAt,
  }) : sections = List.unmodifiable(sections),
       notices = List.unmodifiable(notices);

  final List<ConversationCoachSectionViewModel> sections;
  final List<String> notices;
  final String responseId;
  final String correlationId;
  final bool mockExecution;
  final String providerLabel;
  final String? analyticsSchemaVersion;
  final String? analyticsCalculationVersion;
  final String? sourceEventSchemaVersion;
  final int? inputTokens;
  final int? outputTokens;
  final String? planCode;
  final int? allowanceLimit;
  final int? allowanceRemaining;
  final DateTime? allowanceResetAt;
}
