import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../benchmark/phase6a/benchmark_metrics.dart';
import '../benchmark/phase6a/fixture_catalog.dart';
import '../benchmark/phase6a/fixture_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ground-truth comparison returns exact structured metrics', () async {
    final fixture = (await BenchmarkFixtureCatalog.load()).first;
    final metrics = const ExtractionBenchmarkEvaluator().evaluate(
      fixture,
      _resultFor(fixture),
    );

    expect(metrics.characterAccuracy, 1);
    expect(metrics.wordAccuracy, 1);
    expect(metrics.messageExtractionAccuracy, 1);
    expect(metrics.eventClassificationAccuracy, 1);
    expect(metrics.speakerAssignmentAccuracy, 1);
    expect(metrics.timestampAccuracy, 1);
    expect(metrics.duplicateRemovalAccuracy, 1);
    expect(metrics.orderingAccuracy, 1);
    expect(metrics.warningAccuracy, 1);
    expect(metrics.corrections.total, 0);
  });

  test('benchmark calculations expose Review Studio corrections', () async {
    final fixtures = await BenchmarkFixtureCatalog.load();
    final fixture = fixtures.firstWhere(
      (item) => item.id == 'match_stream_low_contrast_roman_hindi',
    );
    final first = fixture.messages.first;
    final metrics = const ExtractionBenchmarkEvaluator().evaluate(
      fixture,
      _resultFor(
        fixture,
        overrides: {
          first.id: _MessageOverride(
            text: '${first.text} extra',
            speaker: MessageSpeaker.me,
            timestamp: null,
          ),
        },
      ),
    );

    expect(metrics.characterAccuracy, lessThan(1));
    expect(metrics.wordAccuracy, lessThan(1));
    expect(metrics.corrections.text, 1);
    expect(metrics.corrections.speaker, 1);
    expect(metrics.corrections.timestamp, 1);
    expect(metrics.corrections.total, greaterThanOrEqualTo(3));
  });

  test(
    'confidence calibration identifies the low-contrast review item',
    () async {
      final fixtures = await BenchmarkFixtureCatalog.load();
      final fixture = fixtures.firstWhere(
        (item) => item.id == 'match_stream_low_contrast_roman_hindi',
      );
      final metrics = const ExtractionBenchmarkEvaluator().evaluate(
        fixture,
        _resultFor(fixture),
      );

      expect(metrics.manualReviewRate, 0.25);
      expect(metrics.reviewRecall, 1);
      expect(metrics.reviewPrecision, 1);
    },
  );

  test(
    'missing provider confidence safely requires full manual review',
    () async {
      final fixtures = await BenchmarkFixtureCatalog.load();
      final fixture = fixtures.firstWhere(
        (item) => item.id == 'match_stream_low_contrast_roman_hindi',
      );
      final metrics = const ExtractionBenchmarkEvaluator().evaluate(
        fixture,
        _resultFor(fixture, confidenceAvailable: false),
      );

      expect(metrics.manualReviewRate, 1);
      expect(metrics.reviewRecall, 1);
      expect(metrics.reviewPrecision, 0.25);
      expect(metrics.warningAccuracy, 1);
    },
  );
}

OcrExtractionResult _resultFor(
  BenchmarkFixture fixture, {
  bool confidenceAvailable = true,
  Map<String, _MessageOverride> overrides = const {},
}) {
  final messages = [
    for (final expected in fixture.messages)
      _reviewMessage(
        fixture,
        expected,
        overrides[expected.id],
        confidenceAvailable: confidenceAvailable,
      ),
  ];
  final warningCodes = {...fixture.expectedWarnings};
  if (!confidenceAvailable) {
    warningCodes.add(ExtractionWarningCode.confidenceUnavailable);
  }
  return OcrExtractionResult(
    messages: messages,
    events: [
      ...messages,
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
      for (final code in warningCodes)
        ExtractionWarning(code: code, message: 'Synthetic benchmark warning.'),
    ],
    metadata: ExtractionMetadata(
      provider: 'synthetic_evaluator',
      providerVersion: '1',
      extractionVersion: 'phase6a-test',
      preprocessingVersion: 'phase6a-test',
      confidenceAvailable: confidenceAvailable,
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

ReviewMessage _reviewMessage(
  BenchmarkFixture fixture,
  BenchmarkExpectedMessage expected,
  _MessageOverride? override, {
  required bool confidenceAvailable,
}) {
  return ReviewMessage(
    id: expected.id,
    speaker: override?.speaker ?? expected.speaker,
    text: override?.text ?? expected.text,
    timestamp: override?.hasTimestampOverride == true
        ? override!.timestamp
        : expected.timestamp,
    timestampEstimated: false,
    ocrConfidence: confidenceAvailable ? expected.referenceConfidence : null,
    sourceScreenshotIndex: fixture.sourceIndexForMessage(expected.id),
    status: ReviewMessageStatus.extracted,
    visibleTimestampText: expected.visibleTimestampText,
    eventType: expected.eventType,
  );
}

class _MessageOverride {
  const _MessageOverride({this.text, this.speaker, this.timestamp})
    : hasTimestampOverride = true;

  final String? text;
  final MessageSpeaker? speaker;
  final DateTime? timestamp;
  final bool hasTimestampOverride;
}
