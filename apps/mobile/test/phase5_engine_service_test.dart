import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/application/conversation_extraction_service.dart';
import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/real_conversation_ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/data/text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real engine normalizes structure and flags low confidence for review',
    () async {
      final engine = RealConversationOcrEngine(
        preprocessor: const _FakePreprocessor(),
        textRecognitionProvider: _FakeTextProvider(),
      );

      final result = await engine.extract(
        [_source()],
        locale: 'en_GB',
        onProgress: (_) {},
        cancellationToken: ExtractionCancellationToken(),
      );

      expect(result.messages, hasLength(2));
      expect(result.messages.first.speaker, MessageSpeaker.other);
      expect(result.messages.last.speaker, MessageSpeaker.me);
      expect(result.messages.first.timestamp, DateTime(2026, 7, 14, 9, 30));
      expect(result.messages.first.needsReview, isTrue);
      expect(result.messages.last.needsReview, isFalse);
      expect(result.metadata.provider, 'synthetic_provider');
      expect(
        result.metadata.extractionVersion,
        'conversation-extraction-v2-events',
      );
    },
  );

  test('normalization records content-free extraction provenance', () {
    final normalized = ConversationNormalizer.normalize(
      title: 'Synthetic',
      importType: ConversationImportType.screenshot,
      readinessScore: 96,
      messages: [
        _reviewMessage('Hello', MessageSpeaker.other),
        _reviewMessage('Hi', MessageSpeaker.me),
      ],
      sources: const [
        ImportSourceMetadata(
          id: 'source',
          name: 'synthetic.png',
          mimeType: 'image/png',
          byteSize: 64,
          index: 0,
        ),
      ],
      extractionMetadata: const ExtractionMetadata(
        provider: 'synthetic_provider',
        providerVersion: '1',
        extractionVersion: 'conversation-extraction-v1',
        preprocessingVersion: 'image-v1',
        confidenceAvailable: true,
      ),
    );

    expect(normalized.extractionMetadata?.provider, 'synthetic_provider');
    expect(normalized.extractionMetadata?.preprocessingVersion, 'image-v1');
    expect(normalized.messages.first.text, 'Hello');
  });

  test('normalization refuses to guess an unresolved speaker', () {
    expect(
      () => ConversationNormalizer.normalize(
        title: 'Synthetic',
        importType: ConversationImportType.screenshot,
        readinessScore: 50,
        messages: [_reviewMessage('Ambiguous', MessageSpeaker.unknown)],
        sources: const [],
      ),
      throwsStateError,
    );
  });

  test(
    'idempotency reuses a completed extraction without rerunning OCR',
    () async {
      final engine = _CountingEngine();
      final service = ConversationExtractionService(engine);

      for (var request = 0; request < 2; request++) {
        await service.extract(
          [_source()],
          locale: 'en_GB',
          onProgress: (_) {},
          cancellationToken: ExtractionCancellationToken(),
        );
      }

      expect(engine.calls, 1);
    },
  );

  test('transient extraction retries are bounded and reusable', () async {
    final engine = _CountingEngine(transientFailures: 2);
    final service = ConversationExtractionService(engine, maximumRetries: 2);

    final result = await service.extract(
      [_source()],
      locale: 'en_GB',
      onProgress: (_) {},
      cancellationToken: ExtractionCancellationToken(),
    );

    expect(result.metadata.provider, 'counting');
    expect(engine.calls, 3);
  });

  test(
    'cancellation stops extraction and never caches a partial result',
    () async {
      final engine = _CountingEngine(delay: const Duration(milliseconds: 30));
      final service = ConversationExtractionService(engine);
      final cancellation = ExtractionCancellationToken();
      final operation = service.extract(
        [_source()],
        locale: 'en_GB',
        onProgress: (_) {},
        cancellationToken: cancellation,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      cancellation.cancel();

      await expectLater(
        operation,
        throwsA(isA<ExtractionCancelledException>()),
      );
      await service.extract(
        [_source()],
        locale: 'en_GB',
        onProgress: (_) {},
        cancellationToken: ExtractionCancellationToken(),
      );
      expect(engine.calls, 2);
    },
  );
}

TemporaryImportSource _source() => TemporaryImportSource(
  metadata: const ImportSourceMetadata(
    id: 'synthetic-source',
    name: 'synthetic.png',
    mimeType: 'image/png',
    byteSize: 4,
    index: 0,
  ),
  bytes: Uint8List.fromList([1, 2, 3, 4]),
);

ReviewMessage _reviewMessage(String text, MessageSpeaker speaker) {
  return ReviewMessage(
    id: text,
    speaker: speaker,
    text: text,
    timestamp: null,
    timestampEstimated: false,
    ocrConfidence: 0.98,
    sourceScreenshotIndex: 0,
    status: ReviewMessageStatus.edited,
  );
}

class _FakePreprocessor implements ConversationImagePreprocessor {
  const _FakePreprocessor();

  @override
  String get version => 'image-v1';

  @override
  Future<PreprocessedImage> process(
    TemporaryImportSource source, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    return PreprocessedImage(
      sourceIndex: source.metadata.index,
      bytes: Uint8List.fromList([1]),
      width: 400,
      height: 800,
      orientationCorrected: false,
      wasResized: false,
    );
  }
}

class _FakeTextProvider implements TextRecognitionProvider {
  @override
  String get providerId => 'synthetic_provider';

  @override
  String get providerVersion => '1';

  @override
  Future<RecognizedTextPage> recognize(
    PreprocessedImage image, {
    required ExtractionCancellationToken cancellationToken,
  }) async {
    return RecognizedTextPage(
      sourceIndex: image.sourceIndex,
      width: image.width,
      height: image.height,
      lines: const [
        RecognizedLine(
          text: '14/07/2026',
          bounds: OcrBounds(left: 150, top: 20, right: 250, bottom: 40),
          confidence: 0.99,
        ),
        RecognizedLine(
          text: 'Synthetic hello',
          bounds: OcrBounds(left: 12, top: 100, right: 160, bottom: 126),
          confidence: 0.72,
        ),
        RecognizedLine(
          text: '9:30 AM',
          bounds: OcrBounds(left: 12, top: 130, right: 80, bottom: 148),
          confidence: 0.9,
        ),
        RecognizedLine(
          text: 'Synthetic reply',
          bounds: OcrBounds(left: 245, top: 190, right: 390, bottom: 216),
          confidence: 0.98,
        ),
      ],
    );
  }
}

class _CountingEngine implements OcrEngine {
  _CountingEngine({this.transientFailures = 0, this.delay = Duration.zero});

  final int transientFailures;
  final Duration delay;
  int calls = 0;

  @override
  String get providerId => 'counting';

  @override
  String get providerVersion => '1';

  @override
  String get extractionVersion => '1';

  @override
  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    cancellationToken.throwIfCancelled();
    if (calls <= transientFailures) {
      throw const TransientExtractionException('Synthetic transient error.');
    }
    onProgress(1);
    return const OcrExtractionResult(
      messages: [],
      warnings: [],
      metadata: ExtractionMetadata(
        provider: 'counting',
        providerVersion: '1',
        extractionVersion: '1',
        preprocessingVersion: '1',
        confidenceAvailable: true,
      ),
    );
  }
}
