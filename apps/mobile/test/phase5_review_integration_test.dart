import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/data/screenshot_picker.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets(
    'Review Studio renders extraction warnings and confidence state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpConvoCoach(
        tester,
        initialLocation: '/import/screenshots',
        screenshotPicker: _SyntheticPicker(),
        ocrEngine: const _SyntheticEngine(),
      );

      await tester.tap(find.text('Choose screenshots'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extract conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Review studio'), findsOneWidget);
      expect(find.text('Extraction review notes'), findsOneWidget);
      expect(
        find.text('Confirm the speaker for the centered message.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Extraction review notes')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Needs review'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Needs review'), findsOneWidget);
      semantics.dispose();
    },
  );

  test(
    'abandoning extraction clears source bytes and ignores stale results',
    () async {
      final store = InMemoryTemporarySourceStore();
      final container = ProviderContainer(
        overrides: [
          temporarySourceStoreProvider.overrideWithValue(store),
          ocrEngineProvider.overrideWithValue(
            const _SyntheticEngine(delay: Duration(milliseconds: 30)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(conversationImportProvider.notifier);
      await controller.start(ConversationImportType.screenshot);
      await controller.addSources(
        await _SyntheticPicker().pick(startingIndex: 0),
      );
      final extraction = controller.extractScreenshots();

      await controller.cancel();
      expect(await extraction, isFalse);

      expect(await store.readAll(), isEmpty);
      expect(container.read(conversationImportProvider).sources, isEmpty);
      expect(container.read(conversationImportProvider).messages, isEmpty);
      expect(container.read(conversationImportProvider).errorMessage, isNull);
    },
  );

  test(
    'cancelling only processing retains temporary bytes for safe retry',
    () async {
      final store = InMemoryTemporarySourceStore();
      final container = ProviderContainer(
        overrides: [
          temporarySourceStoreProvider.overrideWithValue(store),
          ocrEngineProvider.overrideWithValue(
            const _SyntheticEngine(delay: Duration(milliseconds: 30)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(conversationImportProvider.notifier);
      await controller.start(ConversationImportType.screenshot);
      await controller.addSources(
        await _SyntheticPicker().pick(startingIndex: 0),
      );
      final extraction = controller.extractScreenshots();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.cancelExtraction();

      expect(await extraction, isFalse);
      expect(await store.readAll(), hasLength(1));
      expect(
        container.read(conversationImportProvider).errorMessage,
        contains('safe retry'),
      );
    },
  );
}

class _SyntheticPicker implements ScreenshotPicker {
  @override
  Future<List<TemporaryImportSource>> pick({required int startingIndex}) async {
    return [
      TemporaryImportSource(
        metadata: ImportSourceMetadata(
          id: 'synthetic-source',
          name: 'synthetic.png',
          mimeType: 'image/png',
          byteSize: 4,
          index: startingIndex,
        ),
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ];
  }
}

class _SyntheticEngine implements OcrEngine {
  const _SyntheticEngine({this.delay = Duration.zero});

  final Duration delay;

  @override
  String get providerId => 'synthetic';

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
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    cancellationToken.throwIfCancelled();
    onProgress(1);
    return const OcrExtractionResult(
      messages: [
        ReviewMessage(
          id: 'message-1',
          speaker: MessageSpeaker.other,
          text: 'Synthetic first message',
          timestamp: null,
          timestampEstimated: false,
          ocrConfidence: 0.72,
          sourceScreenshotIndex: 0,
          status: ReviewMessageStatus.extracted,
        ),
        ReviewMessage(
          id: 'message-2',
          speaker: MessageSpeaker.me,
          text: 'Synthetic second message',
          timestamp: null,
          timestampEstimated: false,
          ocrConfidence: 0.98,
          sourceScreenshotIndex: 0,
          status: ReviewMessageStatus.extracted,
        ),
      ],
      warnings: [
        ExtractionWarning(
          code: ExtractionWarningCode.unknownSpeaker,
          message: 'Confirm the speaker for the centered message.',
        ),
      ],
      metadata: ExtractionMetadata(
        provider: 'synthetic',
        providerVersion: '1',
        extractionVersion: '1',
        preprocessingVersion: '1',
        confidenceAvailable: true,
      ),
    );
  }
}
