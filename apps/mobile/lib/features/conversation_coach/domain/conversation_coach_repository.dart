import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';

class ConversationCoachCancellationToken {
  bool _cancelled = false;
  void Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void bind(void Function() onCancel) {
    if (_cancelled) {
      onCancel();
      return;
    }
    _onCancel = onCancel;
  }

  void clear() {
    _onCancel = null;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
    _onCancel = null;
  }
}

abstract interface class ConversationCoachRepository {
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  });
}

abstract interface class ExternalProcessingConsentRepository {
  Future<bool> grantExternalProcessingConsent({
    required ConversationCoachCancellationToken cancellationToken,
  });
}

abstract interface class AIOutputReportingRepository {
  Future<bool> reportOutput({
    required String conversationId,
    required String responseId,
    required CoachOutputReportCategory category,
    required ConversationCoachCancellationToken cancellationToken,
  });
}

class UnavailableConversationCoachRepository
    implements ConversationCoachRepository {
  const UnavailableConversationCoachRepository();

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    return const ConversationCoachRepositoryFailure(
      ConversationCoachFailure(
        code: ConversationCoachErrorCode.conversationUnavailable,
        localizationKey: 'coaching.error.conversation_unavailable',
        retryable: false,
        retryGuidanceLocalizationKey: null,
        correlationId: 'local-unavailable',
      ),
    );
  }
}
