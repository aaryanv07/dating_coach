import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
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
    if (messages.any(
      (message) =>
          !message.isDeleted && message.speaker == MessageSpeaker.unknown,
    )) {
      throw StateError('Every active message needs a confirmed speaker.');
    }
    final normalized = messages
        .where((message) => !message.isDeleted)
        .map(
          (message) => NormalizedConversationMessage(
            id: message.id,
            speaker: switch (message.speaker) {
              MessageSpeaker.me => 'user',
              MessageSpeaker.other => 'other',
              MessageSpeaker.unknown => throw StateError(
                'Every active message needs a confirmed speaker.',
              ),
            },
            text: message.text.trim().replaceAll(RegExp(r'\s+'), ' '),
            timestamp: message.timestamp,
            timestampEstimated: message.timestampEstimated,
            ocrConfidence: message.ocrConfidence,
            sourceScreenshotIndex: message.sourceScreenshotIndex,
            visibleTimestampText: message.visibleTimestampText,
          ),
        )
        .where((message) => message.text.isNotEmpty)
        .toList(growable: false);

    return SavedConversationInput(
      title: title.trim(),
      participantName: 'Other person',
      sourceType: importType.name,
      readinessScore: readinessScore,
      messages: normalized,
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
