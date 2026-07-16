import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';

class SavedConversationSource {
  const SavedConversationSource({
    required this.index,
    required this.mimeType,
    required this.byteSize,
    required this.storageStatus,
  });

  final int index;
  final String? mimeType;
  final int? byteSize;
  final String storageStatus;
}

class SavedExtractionMetadata {
  const SavedExtractionMetadata({
    required this.provider,
    required this.providerVersion,
    required this.extractionVersion,
    required this.preprocessingVersion,
    required this.confidenceAvailable,
  });

  final String provider;
  final String providerVersion;
  final String extractionVersion;
  final String preprocessingVersion;
  final bool confidenceAvailable;
}

class NormalizedConversationMessage {
  const NormalizedConversationMessage({
    required this.id,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.timestampEstimated,
    required this.ocrConfidence,
    required this.sourceScreenshotIndex,
    this.visibleTimestampText,
  });

  final String id;
  final String speaker;
  final String text;
  final DateTime? timestamp;
  final bool timestampEstimated;
  final double? ocrConfidence;
  final int? sourceScreenshotIndex;
  final String? visibleTimestampText;
}

class NormalizedConversationEvent {
  const NormalizedConversationEvent({
    required this.id,
    required this.position,
    required this.eventType,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.timestampEstimated,
    required this.rawTimestampText,
    required this.sourceImageIndex,
    required this.sourceRegionId,
    required this.ocrConfidence,
    required this.classificationConfidence,
    required this.speakerConfidence,
    required this.timestampConfidence,
    required this.relationshipConfidence,
    required this.requiresReview,
    required this.metadata,
    required this.deletedAt,
  });

  final String id;
  final int position;
  final ConversationEventType eventType;
  final String speaker;
  final String? text;
  final DateTime? timestamp;
  final bool timestampEstimated;
  final String? rawTimestampText;
  final int? sourceImageIndex;
  final String? sourceRegionId;
  final double? ocrConfidence;
  final double? classificationConfidence;
  final double? speakerConfidence;
  final double? timestampConfidence;
  final double? relationshipConfidence;
  final bool requiresReview;
  final Map<String, Object?> metadata;
  final DateTime? deletedAt;
}

class NormalizedConversationEventRelationship {
  const NormalizedConversationEventRelationship({
    required this.id,
    required this.sourceEventId,
    required this.targetEventId,
    required this.type,
    required this.confidence,
    required this.metadata,
  });

  final String id;
  final String sourceEventId;
  final String targetEventId;
  final ConversationEventRelationshipType type;
  final double? confidence;
  final Map<String, Object?> metadata;
}

class SavedConversationInput {
  const SavedConversationInput({
    required this.title,
    required this.participantName,
    required this.sourceType,
    required this.readinessScore,
    required this.messages,
    required this.sources,
    this.events = const [],
    this.relationships = const [],
    this.extractionMetadata,
  });

  final String title;
  final String participantName;
  final String sourceType;
  final int readinessScore;
  final List<NormalizedConversationMessage> messages;
  final List<SavedConversationSource> sources;
  final List<NormalizedConversationEvent> events;
  final List<NormalizedConversationEventRelationship> relationships;
  final SavedExtractionMetadata? extractionMetadata;
}

class SavedConversation {
  const SavedConversation({
    required this.id,
    required this.title,
    required this.participantName,
    required this.sourceType,
    required this.readinessScore,
    required this.messages,
    required this.sources,
    required this.updatedAt,
    this.events = const [],
    this.relationships = const [],
    this.extractionMetadata,
  });

  final String id;
  final String title;
  final String participantName;
  final String sourceType;
  final int readinessScore;
  final List<NormalizedConversationMessage> messages;
  final List<SavedConversationSource> sources;
  final DateTime updatedAt;
  final List<NormalizedConversationEvent> events;
  final List<NormalizedConversationEventRelationship> relationships;
  final SavedExtractionMetadata? extractionMetadata;
}
