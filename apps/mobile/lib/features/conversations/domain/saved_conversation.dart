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

class SavedConversationInput {
  const SavedConversationInput({
    required this.title,
    required this.participantName,
    required this.sourceType,
    required this.readinessScore,
    required this.messages,
    required this.sources,
    this.extractionMetadata,
  });

  final String title;
  final String participantName;
  final String sourceType;
  final int readinessScore;
  final List<NormalizedConversationMessage> messages;
  final List<SavedConversationSource> sources;
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
  final SavedExtractionMetadata? extractionMetadata;
}
