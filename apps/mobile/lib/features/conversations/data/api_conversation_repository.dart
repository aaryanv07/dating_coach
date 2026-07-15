import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversations/domain/conversation_repository.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

class ApiConversationRepository implements ConversationRepository {
  const ApiConversationRepository(this._apiClient);

  final ConversationApiClient _apiClient;

  @override
  Future<List<ConversationSummary>> list() async {
    return [
      for (final dto in await _apiClient.listConversations()) dto.toDomain(),
    ];
  }

  @override
  Future<void> delete(String conversationId) {
    return _apiClient.deleteConversation(conversationId);
  }

  @override
  Future<SavedConversation> save(SavedConversationInput conversation) async {
    return (await _apiClient.saveConversation(conversation)).toDomain();
  }

  @override
  Future<SavedConversation?> get(String conversationId) async {
    return (await _apiClient.getConversation(conversationId))?.toDomain();
  }
}
