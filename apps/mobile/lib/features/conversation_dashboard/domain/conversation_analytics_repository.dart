import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_snapshot.dart';

abstract interface class ConversationAnalyticsRepository {
  Future<ConversationAnalyticsSnapshotV1?> getForConversation(
    String conversationId,
  );
}

class UnavailableConversationAnalyticsRepository
    implements ConversationAnalyticsRepository {
  const UnavailableConversationAnalyticsRepository();

  @override
  Future<ConversationAnalyticsSnapshotV1?> getForConversation(
    String conversationId,
  ) async {
    return null;
  }
}
