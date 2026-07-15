import 'package:convo_coach/features/conversations/data/conversation_summary_dto.dart';
import 'package:convo_coach/features/conversations/data/saved_conversation_dto.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

abstract interface class ConversationApiClient {
  Future<List<ConversationSummaryDto>> listConversations();

  Future<void> deleteConversation(String conversationId);

  Future<SavedConversationDto> saveConversation(SavedConversationInput input);

  Future<SavedConversationDto?> getConversation(String conversationId);
}

class MockConversationApiClient implements ConversationApiClient {
  MockConversationApiClient({
    List<ConversationSummaryDto>? conversations,
    this.latency = Duration.zero,
  }) : _conversations = List.of(conversations ?? _previewConversations);

  static final List<ConversationSummaryDto> _previewConversations = [
    ConversationSummaryDto(
      id: 'preview-1',
      title: 'Weekend plans',
      participantName: 'Sam',
      messageCount: 18,
      updatedAt: DateTime.utc(2026, 7, 14, 9, 30),
    ),
    ConversationSummaryDto(
      id: 'preview-2',
      title: 'Coffee after work',
      participantName: 'Alex',
      messageCount: 9,
      updatedAt: DateTime.utc(2026, 7, 13, 18, 15),
    ),
  ];

  final List<ConversationSummaryDto> _conversations;
  final Map<String, SavedConversationDto> _details = {};
  final Duration latency;
  int _nextId = 1;

  @override
  Future<List<ConversationSummaryDto>> listConversations() async {
    await Future<void>.delayed(latency);
    return [
      for (final conversation in _conversations)
        ConversationSummaryDto.fromJson(conversation.toJson()),
    ];
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await Future<void>.delayed(latency);
    _conversations.removeWhere(
      (conversation) => conversation.id == conversationId,
    );
    _details.remove(conversationId);
  }

  @override
  Future<SavedConversationDto> saveConversation(
    SavedConversationInput input,
  ) async {
    await Future<void>.delayed(latency);
    final now = DateTime.now().toUtc();
    final id = 'import-${_nextId++}';
    final detail = SavedConversationDto.fromDomain(
      input,
      id: id,
      updatedAt: now,
    );
    _details[id] = detail;
    _conversations.insert(
      0,
      ConversationSummaryDto(
        id: id,
        title: input.title,
        participantName: input.participantName,
        messageCount: input.messages.length,
        updatedAt: now,
      ),
    );
    return detail;
  }

  @override
  Future<SavedConversationDto?> getConversation(String conversationId) async {
    await Future<void>.delayed(latency);
    return _details[conversationId];
  }
}
