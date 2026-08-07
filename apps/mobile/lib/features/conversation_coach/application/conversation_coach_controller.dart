import 'dart:async';
import 'dart:io';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/conversation_coach/data/conversation_coach_transport.dart';
import 'package:convo_coach/features/conversation_coach/data/http_conversation_coach_repository.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_repository.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final conversationCoachEntryAvailableProvider = Provider<bool>(
  (ref) =>
      AppConfig.conversationCoachPreviewEnabled &&
      AppConfig.apiBaseUrl.isNotEmpty &&
      AppConfig.runtime.authenticatedApiConfigured,
);

final conversationCoachRepositoryProvider =
    Provider<ConversationCoachRepository>((ref) {
      if (!ref.watch(conversationCoachEntryAvailableProvider)) {
        return const UnavailableConversationCoachRepository();
      }
      final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
      if (baseUri == null || !baseUri.hasScheme) {
        return const UnavailableConversationCoachRepository();
      }
      final tokens = ref.watch(authenticationAccessTokenProvider);
      return HttpConversationCoachRepository(
        baseUri: baseUri,
        accessTokenProvider: tokens.accessToken,
      );
    });

final conversationCoachProvider = NotifierProvider.autoDispose
    .family<ConversationCoachController, ConversationCoachState, String>(
      ConversationCoachController.new,
    );

class ConversationCoachController extends Notifier<ConversationCoachState> {
  ConversationCoachController(this.conversationId);

  final String conversationId;
  ConversationCoachCancellationToken? _token;
  bool _disposed = false;

  @override
  ConversationCoachState build() {
    ref.onDispose(() {
      _disposed = true;
      _token?.cancel();
    });
    if (!ref.watch(conversationCoachEntryAvailableProvider)) {
      return const ConversationCoachUnavailable();
    }
    Future<void>.microtask(load);
    return const ConversationCoachLoading();
  }

  Future<void> load() async {
    if (!ref.read(conversationCoachEntryAvailableProvider)) {
      state = const ConversationCoachUnavailable();
      return;
    }
    _token?.cancel();
    final token = ConversationCoachCancellationToken();
    _token = token;
    state = const ConversationCoachLoading();
    try {
      final result = await ref
          .read(conversationCoachRepositoryProvider)
          .fetchPreview(conversationId, cancellationToken: token)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              token.cancel();
              return const ConversationCoachRepositoryFailure(
                ConversationCoachFailure(
                  code: ConversationCoachErrorCode.timedOut,
                  localizationKey: 'coaching.error.timed_out',
                  retryable: true,
                  retryGuidanceLocalizationKey:
                      'coaching.error.timed_out.retry',
                  correlationId: 'local-timeout',
                ),
              );
            },
          );
      if (_disposed || _token != token) return;
      state = _map(result);
    } on ConversationCoachTransportException {
      if (!_disposed && _token == token) {
        state = const ConversationCoachUnsupported();
      }
    } on SocketException {
      if (!_disposed && _token == token) {
        state = const ConversationCoachNetworkUnavailable();
      }
    } on HttpException {
      if (!_disposed && _token == token) {
        state = token.isCancelled
            ? const ConversationCoachCancelled()
            : const ConversationCoachNetworkUnavailable();
      }
    } on Object {
      if (!_disposed && _token == token) {
        state = token.isCancelled
            ? const ConversationCoachCancelled()
            : const ConversationCoachSafeFailure();
      }
    } finally {
      if (_token == token) _token = null;
    }
  }

  void cancel() {
    _token?.cancel();
    _token = null;
    state = const ConversationCoachCancelled();
  }

  Future<void> grantExternalProcessingConsent() async {
    final repository = ref.read(conversationCoachRepositoryProvider);
    if (repository is! ExternalProcessingConsentRepository) {
      state = const ConversationCoachSafeFailure();
      return;
    }
    final consentRepository = repository as ExternalProcessingConsentRepository;
    _token?.cancel();
    final token = ConversationCoachCancellationToken();
    _token = token;
    state = const ConversationCoachGrantingConsent();
    try {
      final granted = await consentRepository.grantExternalProcessingConsent(
        cancellationToken: token,
      );
      if (_disposed || _token != token) return;
      if (!granted) {
        state = const ConversationCoachSafeFailure();
        return;
      }
      _token = null;
      await load();
    } on SocketException {
      if (!_disposed && _token == token) {
        state = const ConversationCoachNetworkUnavailable();
      }
    } on Object {
      if (!_disposed && _token == token) {
        state = const ConversationCoachSafeFailure();
      }
    } finally {
      if (_token == token) _token = null;
    }
  }

  ConversationCoachState _map(ConversationCoachRepositoryResult result) {
    return switch (result) {
      ConversationCoachRepositorySuccess(:final preview)
          when preview.sections.isEmpty =>
        const ConversationCoachEmpty(),
      ConversationCoachRepositorySuccess(:final preview) =>
        ConversationCoachReady(_toViewModel(preview)),
      ConversationCoachRepositoryFailure(:final failure) =>
        switch (failure.code) {
          ConversationCoachErrorCode.featureDisabled =>
            const ConversationCoachFeatureDisabled(),
          ConversationCoachErrorCode.mockDisabled =>
            const ConversationCoachMockDisabled(),
          ConversationCoachErrorCode.consentRequired =>
            const ConversationCoachConsentRequired(),
          ConversationCoachErrorCode.externalProcessingConsentRequired =>
            const ConversationCoachExternalConsentRequired(),
          ConversationCoachErrorCode.reviewIncomplete =>
            const ConversationCoachReviewIncomplete(),
          ConversationCoachErrorCode.schemaUnsupported ||
          ConversationCoachErrorCode.incompleteTimeline ||
          ConversationCoachErrorCode.capabilityUnsupported =>
            const ConversationCoachUnsupported(),
          ConversationCoachErrorCode.cancelled =>
            const ConversationCoachCancelled(),
          ConversationCoachErrorCode.timedOut =>
            const ConversationCoachTimedOut(),
          ConversationCoachErrorCode.providerUnavailable ||
          ConversationCoachErrorCode.responseValidationFailed ||
          ConversationCoachErrorCode.safetyRejected =>
            const ConversationCoachExecutionFailed(),
          ConversationCoachErrorCode.allowanceExhausted =>
            const ConversationCoachAllowanceExhausted(),
          ConversationCoachErrorCode.rateLimited ||
          ConversationCoachErrorCode.idempotencyInProgress =>
            const ConversationCoachRateLimited(),
          ConversationCoachErrorCode.budgetExhausted ||
          ConversationCoachErrorCode.usageUnavailable =>
            const ConversationCoachBudgetUnavailable(),
          ConversationCoachErrorCode.idempotencyRequired ||
          ConversationCoachErrorCode.idempotencyConflict ||
          ConversationCoachErrorCode.idempotencyReplayed =>
            const ConversationCoachSafeFailure(),
          ConversationCoachErrorCode.authenticationRequired ||
          ConversationCoachErrorCode.authorizationFailed ||
          ConversationCoachErrorCode.conversationUnavailable =>
            const ConversationCoachUnavailable(),
          ConversationCoachErrorCode.internalSafeFailure =>
            const ConversationCoachSafeFailure(),
        },
    };
  }

  ConversationCoachPreviewViewModel _toViewModel(
    ConversationCoachPreview preview,
  ) {
    final calculationVersions = preview.calculationVersions;
    return ConversationCoachPreviewViewModel(
      sections: [
        for (final section in preview.sections)
          ConversationCoachSectionViewModel(
            identifier: section.identifier,
            heading: preview.mockExecution
                ? _copyFor(section.headingLocalizationKey)
                : section.headingLocalizationKey,
            semanticLabel: preview.mockExecution
                ? _copyFor(section.semanticLabelLocalizationKey)
                : section.semanticLabelLocalizationKey,
            status: section.status,
            items:
                section.displayItems ??
                [for (final key in section.itemLocalizationKeys) _copyFor(key)],
            evidenceReferenceCount: section.evidenceReferenceCount,
          ),
      ],
      notices: preview.mockExecution
          ? [for (final key in preview.notices) _copyFor(key)]
          : preview.notices,
      responseId: preview.responseId,
      correlationId: preview.correlationId,
      mockExecution: preview.mockExecution,
      providerLabel: preview.providerLabel,
      analyticsSchemaVersion: calculationVersions?.analyticsSchemaVersion,
      analyticsCalculationVersion:
          calculationVersions?.analyticsCalculationVersion,
      sourceEventSchemaVersion: calculationVersions?.sourceEventSchemaVersion,
      inputTokens: preview.inputTokens,
      outputTokens: preview.outputTokens,
      planCode: preview.planCode,
      allowanceLimit: preview.allowanceLimit,
      allowanceRemaining: preview.allowanceRemaining,
      allowanceResetAt: preview.allowanceResetAt,
    );
  }
}

String _copyFor(String key) => switch (key) {
  'coaching.section.supported.heading' => 'Foundation available',
  'coaching.section.supported.semantic' =>
    'Available structural foundation capabilities',
  'coaching.section.unavailable.heading' => 'Coaching remains unavailable',
  'coaching.section.unavailable.semantic' =>
    'Unavailable coaching capabilities',
  'coaching.section.explanations.heading' => 'Explanation placeholders',
  'coaching.section.explanations.semantic' =>
    'Structural explanation placeholders only',
  'coaching.section.safety.heading' => 'Safety notices',
  'coaching.section.safety.semantic' => 'Important preview safety notices',
  'coaching.capability.response_schema' => 'Validated response schema',
  'coaching.capability.evidence_references' =>
    'Content-free evidence references',
  'coaching.capability.explanation_placeholders' =>
    'Explanation placeholder structure',
  'coaching.capability.safety_notices' => 'Safety notice structure',
  'coaching.capability.coaching_guidance.unavailable' =>
    'Coaching guidance is not available',
  'coaching.capability.recommendations.unavailable' =>
    'Recommendations are not available',
  'coaching.capability.reply_drafting.unavailable' =>
    'Reply drafting is not available',
  'coaching.capability.first_message_drafting.unavailable' =>
    'First-message drafting is not available',
  'coaching.capability.communication_dna.unavailable' =>
    'Communication profiling is not available',
  'coaching.capability.relationship_scoring.unavailable' =>
    'Relationship scoring is not available',
  'coaching.capability.compatibility_scoring.unavailable' =>
    'Compatibility scoring is not available',
  'coaching.foundation.placeholder' =>
    'A validated explanation container is present, with no generated explanation.',
  'coaching.foundation.no_coaching_generated' =>
    'No coaching, advice, or generated message was produced.',
  'coaching.foundation.mock_only' =>
    'This is a deterministic mock infrastructure preview.',
  _ => 'Unavailable',
};
