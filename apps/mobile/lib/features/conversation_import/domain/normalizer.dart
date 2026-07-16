import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

abstract final class ConversationNormalizer {
  static SavedConversationInput normalize({
    required String title,
    required ConversationImportType importType,
    required int readinessScore,
    required List<ReviewMessage> messages,
    required List<ImportSourceMetadata> sources,
    ExtractionMetadata? extractionMetadata,
  }) {
    final active = messages.where((event) => !event.isDeleted);
    if (active.any(
      (event) => event.speaker == MessageSpeaker.unknown || event.needsReview,
    )) {
      throw StateError('Every active event must be reviewed and assigned.');
    }

    String speakerName(MessageSpeaker speaker) => switch (speaker) {
      MessageSpeaker.me => 'user',
      MessageSpeaker.other => 'other',
      MessageSpeaker.system => 'system',
      MessageSpeaker.unknown => 'unknown',
    };

    String normalizedText(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ');

    final events = [
      for (var position = 0; position < messages.length; position++)
        NormalizedConversationEvent(
          id: messages[position].id,
          position: position,
          eventType: messages[position].eventType,
          speaker: speakerName(messages[position].speaker),
          text: normalizedText(messages[position].text).isEmpty
              ? null
              : normalizedText(messages[position].text),
          timestamp: messages[position].timestamp,
          timestampEstimated: messages[position].timestampEstimated,
          rawTimestampText: messages[position].visibleTimestampText,
          sourceImageIndex: messages[position].sourceScreenshotIndex,
          sourceRegionId: messages[position].sourceRegionId,
          ocrConfidence: messages[position].ocrConfidence,
          classificationConfidence: messages[position].classificationConfidence,
          speakerConfidence: messages[position].speakerConfidence,
          timestampConfidence: messages[position].timestampConfidence,
          relationshipConfidence: messages[position].relationshipConfidence,
          requiresReview: messages[position].needsReview,
          metadata: Map.unmodifiable(messages[position].metadata),
          deletedAt: messages[position].deletedAt,
        ),
    ];
    final relationships = <NormalizedConversationEventRelationship>[
      for (final event in messages)
        for (final relationship in event.relationships)
          NormalizedConversationEventRelationship(
            id: relationship.id,
            sourceEventId: relationship.sourceEventId,
            targetEventId: relationship.targetEventId,
            type: relationship.type,
            confidence: relationship.confidence,
            metadata: Map.unmodifiable(relationship.metadata),
          ),
    ];

    // Legacy compatibility is a projection only. Reactions and structural
    // events never become message rows and no dual-write happens implicitly.
    final normalizedMessages = messages
        .where(
          (event) =>
              !event.isDeleted &&
              event.eventType.countsAsMessage &&
              (event.speaker == MessageSpeaker.me ||
                  event.speaker == MessageSpeaker.other),
        )
        .map(
          (event) => NormalizedConversationMessage(
            id: event.id,
            speaker: speakerName(event.speaker),
            text: normalizedText(event.text),
            timestamp: event.timestamp,
            timestampEstimated: event.timestampEstimated,
            ocrConfidence: event.ocrConfidence,
            sourceScreenshotIndex: event.sourceScreenshotIndex,
            visibleTimestampText: event.visibleTimestampText,
          ),
        )
        .where((message) => message.text.isNotEmpty)
        .toList(growable: false);

    return SavedConversationInput(
      title: title.trim(),
      participantName: 'Other person',
      sourceType: importType.name,
      readinessScore: readinessScore,
      messages: List.unmodifiable(normalizedMessages),
      events: List.unmodifiable(events),
      relationships: List.unmodifiable(relationships),
      sources: [
        for (final source in sources)
          SavedConversationSource(
            index: source.index,
            mimeType: source.mimeType,
            byteSize: source.byteSize,
            storageStatus: importType == ConversationImportType.screenshot
                ? 'deleted'
                : 'not_stored',
          ),
      ],
      extractionMetadata: extractionMetadata == null
          ? null
          : SavedExtractionMetadata(
              provider: extractionMetadata.provider,
              providerVersion: extractionMetadata.providerVersion,
              extractionVersion: extractionMetadata.extractionVersion,
              preprocessingVersion: extractionMetadata.preprocessingVersion,
              confidenceAvailable: extractionMetadata.confidenceAvailable,
            ),
    );
  }
}

enum ConversationImportType { screenshot, paste }
