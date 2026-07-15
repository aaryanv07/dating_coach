import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

class SavedConversationDto {
  const SavedConversationDto({
    required this.id,
    required this.title,
    required this.participantName,
    required this.sourceType,
    required this.readinessScore,
    required this.messages,
    required this.sources,
    required this.updatedAt,
    this.extractionMetadata,
  });

  factory SavedConversationDto.fromDomain(
    SavedConversationInput input, {
    required String id,
    required DateTime updatedAt,
  }) {
    return SavedConversationDto(
      id: id,
      title: input.title,
      participantName: input.participantName,
      sourceType: input.sourceType,
      readinessScore: input.readinessScore,
      messages: input.messages,
      sources: input.sources,
      updatedAt: updatedAt,
      extractionMetadata: input.extractionMetadata,
    );
  }

  final String id;
  final String title;
  final String participantName;
  final String sourceType;
  final int readinessScore;
  final List<NormalizedConversationMessage> messages;
  final List<SavedConversationSource> sources;
  final DateTime updatedAt;
  final SavedExtractionMetadata? extractionMetadata;

  SavedConversation toDomain() {
    return SavedConversation(
      id: id,
      title: title,
      participantName: participantName,
      sourceType: sourceType,
      readinessScore: readinessScore,
      messages: List.unmodifiable(messages),
      sources: List.unmodifiable(sources),
      updatedAt: updatedAt,
      extractionMetadata: extractionMetadata,
    );
  }
}
