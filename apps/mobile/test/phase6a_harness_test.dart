import 'dart:io';

import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../benchmark/phase6a/benchmark_harness.dart';
import '../benchmark/phase6a/benchmark_report.dart';
import '../benchmark/phase6a/benchmark_session.dart';
import '../benchmark/phase6a/fixture_catalog.dart';
import '../benchmark/phase6a/fixture_models.dart';
import '../benchmark/phase6a/report_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'harness measures successful cases, cancellation, and cleanup',
    () async {
      final fixture = (await BenchmarkFixtureCatalog.load()).first;
      const harness = ExtractionBenchmarkHarness();
      final report = await harness.run(
        fixtures: [fixture],
        engineFactory: (_) => _FixtureEngine(fixture),
        sessionEnvironment: _syntheticSession,
        nativeDeviceRun: false,
      );

      expect(report.summary.completedCount, 1);
      expect(report.summary.failedCount, 0);
      expect(report.cancellationProbePassed, isTrue);
      expect(report.summary.cleanupSuccessRate, 1);
      expect(report.cases.single.metrics?.corrections.total, 0);
      expect(
        report.qualityGates
            .firstWhere((gate) => gate.id == 'native_device_run')
            .passed,
        isFalse,
      );
    },
  );

  test(
    'harness records redacted failure categories and still cleans up',
    () async {
      final fixture = (await BenchmarkFixtureCatalog.load()).first;
      const harness = ExtractionBenchmarkHarness();
      final report = await harness.run(
        fixtures: [fixture],
        engineFactory: (_) => _FixtureEngine(fixture, fail: true),
        sessionEnvironment: _syntheticSession,
        nativeDeviceRun: false,
      );

      expect(report.summary.failedCount, 1);
      expect(report.cases.single.status, BenchmarkCaseStatus.failed);
      expect(report.cases.single.failureCategory, 'ExtractionException');
      expect(report.cases.single.cleanupSucceeded, isTrue);
      expect(
        report.toJson().toString(),
        isNot(contains('private fixture text')),
      );
    },
  );

  test('mid-flight cancellation discards the synthetic result', () async {
    final fixture = (await BenchmarkFixtureCatalog.load()).first;
    final token = ExtractionCancellationToken();
    final operation =
        _FixtureEngine(
          fixture,
          delay: const Duration(milliseconds: 30),
        ).extract(
          const <TemporaryImportSource>[],
          locale: 'en_IN',
          onProgress: (_) {},
          cancellationToken: token,
        );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    token.cancel();

    await expectLater(operation, throwsA(isA<ExtractionCancelledException>()));
  });

  test(
    'JSON and Markdown exports contain metrics but no transcript data',
    () async {
      final fixture = (await BenchmarkFixtureCatalog.load()).first;
      final report = await const ExtractionBenchmarkHarness().run(
        fixtures: [fixture],
        engineFactory: (_) => _FixtureEngine(fixture),
        sessionEnvironment: _syntheticSession,
        nativeDeviceRun: false,
      );
      final output = await Directory.systemTemp.createTemp(
        'convocoach-phase6a-export-',
      );
      try {
        final paths = await const BenchmarkReportExporter().export(
          report.toJson(),
          output,
        );
        final json = await paths.json.readAsString();
        final markdown = await paths.markdown.readAsString();
        for (final message in fixture.messages) {
          expect(json, isNot(contains(message.text)));
          expect(markdown, isNot(contains(message.text)));
        }
        expect(json.toLowerCase(), isNot(contains('sha256')));
        expect(markdown.toLowerCase(), isNot(contains('screenshot path')));
        expect(json, contains('character_accuracy'));
        expect(markdown, contains('Quality Gates'));
      } finally {
        await output.delete(recursive: true);
      }
    },
  );
}

const _syntheticSession = BenchmarkSessionEnvironment(
  platform: 'synthetic_test',
  deviceModel: 'synthetic_device_class',
  osVersion: '1',
  flutterVersion: 'test',
  mlKitVersion: 'not_exercised',
  extractionVersion: 'phase6a-test',
);

class _FixtureEngine implements OcrEngine {
  const _FixtureEngine(
    this.fixture, {
    this.fail = false,
    this.delay = Duration.zero,
  });

  final BenchmarkFixture fixture;
  final bool fail;
  final Duration delay;

  @override
  String get providerId => 'synthetic_harness';

  @override
  String get providerVersion => '1';

  @override
  String get extractionVersion => 'phase6a-test';

  @override
  Future<OcrExtractionResult> extract(
    List<TemporaryImportSource> sources, {
    required String locale,
    required void Function(double progress) onProgress,
    required ExtractionCancellationToken cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    cancellationToken.throwIfCancelled();
    if (fail) throw const ExtractionException('private fixture text');
    onProgress(1);
    return OcrExtractionResult(
      messages: [
        for (final expected in fixture.messages)
          ReviewMessage(
            id: expected.id,
            speaker: expected.speaker,
            text: expected.text,
            timestamp: expected.timestamp,
            timestampEstimated: false,
            ocrConfidence: expected.referenceConfidence,
            sourceScreenshotIndex: fixture.sourceIndexForMessage(expected.id),
            status: ReviewMessageStatus.extracted,
            visibleTimestampText: expected.visibleTimestampText,
            eventType: expected.eventType,
          ),
      ],
      events: [
        for (final expected in fixture.messages)
          ReviewMessage(
            id: expected.id,
            speaker: expected.speaker,
            text: expected.text,
            timestamp: expected.timestamp,
            timestampEstimated: false,
            ocrConfidence: expected.referenceConfidence,
            sourceScreenshotIndex: fixture.sourceIndexForMessage(expected.id),
            status: ReviewMessageStatus.extracted,
            visibleTimestampText: expected.visibleTimestampText,
            eventType: expected.eventType,
          ),
        for (final expected in fixture.events)
          ReviewMessage(
            id: expected.id,
            speaker: expected.speaker,
            text: expected.text,
            timestamp: null,
            timestampEstimated: false,
            ocrConfidence: 0.97,
            sourceScreenshotIndex: fixture.sourceIndexForEvent(expected.id),
            status: ReviewMessageStatus.extracted,
            eventType: expected.eventType,
          ),
        for (final page in fixture.pages)
          if (page.dateLabel case final label?)
            ReviewMessage(
              id: 'date-${page.sourceIndex}',
              speaker: MessageSpeaker.system,
              text: label,
              timestamp: null,
              timestampEstimated: false,
              ocrConfidence: 0.99,
              sourceScreenshotIndex: page.sourceIndex,
              status: ReviewMessageStatus.extracted,
              eventType: ConversationEventType.dateSeparator,
            ),
        for (final page in fixture.pages)
          for (var index = 0; index < page.reactions.length; index++)
            if (page.reactions[index].recognizeAsText)
              ReviewMessage(
                id: 'reaction-${page.sourceIndex}-$index',
                speaker: MessageSpeaker.unknown,
                text: page.reactions[index].text,
                timestamp: null,
                timestampEstimated: false,
                ocrConfidence: 0.9,
                sourceScreenshotIndex: page.sourceIndex,
                status: ReviewMessageStatus.extracted,
                eventType: ConversationEventType.reaction,
              ),
      ],
      warnings: [
        for (final code in fixture.expectedWarnings)
          ExtractionWarning(code: code, message: 'Synthetic warning.'),
      ],
      metadata: const ExtractionMetadata(
        provider: 'synthetic_harness',
        providerVersion: '1',
        extractionVersion: 'phase6a-test',
        preprocessingVersion: 'phase6a-test',
        confidenceAvailable: true,
      ),
      diagnostics: ExtractionDiagnostics(
        processedScreenshotCount: fixture.pages.length,
        candidateMessageCount:
            fixture.messages.length + fixture.expectedDuplicateIds.length,
        duplicateMessagesRemoved: fixture.expectedDuplicateIds.length,
        unknownSpeakerCount: 0,
        orderedSourceIndices: fixture.expectedSourceOrder,
      ),
    );
  }
}
