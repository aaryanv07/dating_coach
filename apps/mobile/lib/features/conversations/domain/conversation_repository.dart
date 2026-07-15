import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

abstract interface class ConversationRepository {
  Future<List<ConversationSummary>> list();

  Future<void> delete(String conversationId);

  Future<SavedConversation> save(SavedConversationInput conversation);

  Future<SavedConversation?> get(String conversationId);
}
