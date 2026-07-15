import 'dart:async';

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

class MockOcrEngine implements OcrEngine {
  const MockOcrEngine({this.stepDelay = const Duration(milliseconds: 40)});

  final Duration stepDelay;

  @override
  String get providerId => 'mock_ocr';

  @override
  String get providerVersion => '1';

  @override
  String get extractionVersion => 'conversation-extraction-v1';

  @override
  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    final messages = <ReviewMessage>[];
    for (var index = 0; index < sources.length; index++) {
      cancellationToken.throwIfCancelled();
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      cancellationToken.throwIfCancelled();
      final sourceIndex = sources[index].metadata.index;
      messages.addAll(_messagesForSource(sourceIndex));
      onProgress((index + 1) / sources.length);
    }
    return OcrExtractionResult(
      messages: List.unmodifiable(messages),
      warnings: const [],
      metadata: const ExtractionMetadata(
        provider: 'mock_ocr',
        providerVersion: '1',
        extractionVersion: 'conversation-extraction-v1',
        preprocessingVersion: 'mock-no-image-processing',
        confidenceAvailable: true,
      ),
    );
  }

  List<ReviewMessage> _messagesForSource(int sourceIndex) {
    return [
      ReviewMessage(
        id: 'ocr-$sourceIndex-1',
        speaker: MessageSpeaker.other,
        text: sourceIndex == 0
            ? 'Hey, are we still on for coffee tomorrow?'
            : 'The place near the park looks good to me.',
        timestamp: null,
        timestampEstimated: false,
        ocrConfidence: 0.98,
        sourceScreenshotIndex: sourceIndex,
        status: ReviewMessageStatus.extracted,
      ),
      ReviewMessage(
        id: 'ocr-$sourceIndex-2',
        speaker: MessageSpeaker.me,
        text: sourceIndex == 0
            ? 'Yes! Would 11 work for you?'
            : 'Perfect, see you then.',
        timestamp: null,
        timestampEstimated: false,
        ocrConfidence: sourceIndex == 0 ? 0.76 : 0.93,
        sourceScreenshotIndex: sourceIndex,
        status: ReviewMessageStatus.extracted,
      ),
    ];
  }
}

class MockConversationTextParser implements ConversationTextParser {
  @override
  List<ReviewMessage> parse(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return [
      for (var index = 0; index < lines.length; index++)
        ReviewMessage(
          id: 'paste-$index',
          speaker: index.isEven ? MessageSpeaker.other : MessageSpeaker.me,
          text: _removeSpeakerPrefix(lines[index]),
          timestamp: null,
          timestampEstimated: false,
          ocrConfidence: null,
          sourceScreenshotIndex: null,
          status: ReviewMessageStatus.extracted,
        ),
    ];
  }

  String _removeSpeakerPrefix(String line) {
    return line.replaceFirst(
      RegExp(r'^(me|you|them|other|[a-z]+)\s*:\s*', caseSensitive: false),
      '',
    );
  }
}
