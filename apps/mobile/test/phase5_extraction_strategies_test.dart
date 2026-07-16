import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/message_region_grouper.dart';
import 'package:convo_coach/features/conversation_import/domain/overlap_detector.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversation_import/domain/screenshot_ordering.dart';
import 'package:convo_coach/features/conversation_import/domain/speaker_assignment.dart';
import 'package:convo_coach/features/conversation_import/domain/timestamp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bounding-box grouping', () {
    test(
      'groups nearby bubble lines and preserves emoji and visible order',
      () {
        const grouper = GeometryMessageRegionGrouper();
        final regions = grouper.group(
          RecognizedTextPage(
            sourceIndex: 0,
            width: 400,
            height: 800,
            lines: const [
              RecognizedLine(
                text: '14/07/2026',
                bounds: OcrBounds(left: 150, top: 20, right: 250, bottom: 40),
                confidence: 0.99,
              ),
              RecognizedLine(
                text: 'Hey 👋',
                bounds: OcrBounds(left: 20, top: 100, right: 110, bottom: 122),
                confidence: 0.94,
              ),
              RecognizedLine(
                text: 'still free?',
                bounds: OcrBounds(left: 20, top: 125, right: 145, bottom: 147),
                confidence: 0.86,
              ),
              RecognizedLine(
                text: '9:30 AM',
                bounds: OcrBounds(left: 22, top: 150, right: 90, bottom: 168),
                confidence: 0.91,
              ),
              RecognizedLine(
                text: 'Yes, absolutely',
                bounds: OcrBounds(left: 250, top: 210, right: 380, bottom: 234),
                confidence: 0.98,
              ),
            ],
          ),
          locale: 'en_GB',
        );

        expect(regions, hasLength(3));
        expect(
          regions.first.eventTypeHint,
          ConversationEventType.dateSeparator,
        );
        expect(regions.first.text, '14/07/2026');
        expect(regions[1].text, 'Hey 👋 still free?');
        expect(regions[1].timestamp, DateTime(2026, 7, 14, 9, 30));
        expect(regions[1].visibleTimestampText, '9:30 AM');
        expect(regions[1].confidence, closeTo(0.9, 0.03));
        expect(regions.last.text, 'Yes, absolutely');
      },
    );
  });

  group('speaker assignment', () {
    const strategy = GeometrySpeakerAssignment();

    test('uses edge geometry and preserves ambiguous center as unknown', () {
      expect(
        strategy.assign(_region(left: 12, right: 180), pageWidth: 400),
        MessageSpeaker.other,
      );
      expect(
        strategy.assign(_region(left: 220, right: 390), pageWidth: 400),
        MessageSpeaker.me,
      );
      expect(
        strategy.assign(_region(left: 90, right: 310), pageWidth: 400),
        MessageSpeaker.unknown,
      );
    });
  });

  group('timestamp parsing', () {
    const parser = LocaleAwareTimestampParser();

    test('parses numeric dates according to locale', () {
      final us = parser.parse('07/14/2026', locale: 'en_US');
      final gb = parser.parse('14/07/2026', locale: 'en_GB');

      expect((us?.year, us?.month, us?.day), (2026, 7, 14));
      expect((gb?.year, gb?.month, gb?.day), (2026, 7, 14));
    });

    test('never fabricates a date for a visible time-only token', () {
      final time = parser.parse('11:42 PM', locale: 'en_US');

      expect(time?.precision, TimestampPrecision.time);
      expect(time?.value, isNull);
      expect(
        resolveVisibleTimestamp(dateContext: null, timestamp: time),
        isNull,
      );
    });

    test('extracts a trailing timestamp without rewriting message content', () {
      final result = parser.extractTrailing(
        'See you there 😊 18:05',
        locale: 'en_GB',
      );

      expect(result?.messageText, 'See you there 😊');
      expect(result?.timestamp.hour, 18);
      expect(result?.timestamp.minute, 5);
    });
  });

  group('screenshot ordering and overlap', () {
    test('orders fully timestamped screenshots and warns about large gaps', () {
      final later = ExtractedScreenshot(
        sourceIndex: 0,
        regions: [_region(text: 'Later', timestamp: DateTime(2026, 7, 15, 10))],
      );
      final earlier = ExtractedScreenshot(
        sourceIndex: 1,
        regions: [
          _region(text: 'Earlier', timestamp: DateTime(2026, 7, 14, 10)),
        ],
      );

      const strategy = TimestampScreenshotOrdering();
      final result = strategy.order([later, earlier]);

      expect(result.screenshots.map((page) => page.sourceIndex), [1, 0]);
      expect(
        result.warnings.map((warning) => warning.code),
        containsAll([
          ExtractionWarningCode.screenshotOrderAdjusted,
          ExtractionWarningCode.timelineGap,
        ]),
      );
    });

    test(
      'preserves picker order when screenshot timestamps are incomplete',
      () {
        final result = const TimestampScreenshotOrdering().order([
          ExtractedScreenshot(sourceIndex: 0, regions: [_region(text: 'A')]),
          ExtractedScreenshot(sourceIndex: 1, regions: [_region(text: 'B')]),
        ]);

        expect(result.screenshots.map((page) => page.sourceIndex), [0, 1]);
        expect(
          result.warnings.single.code,
          ExtractionWarningCode.screenshotOrderUncertain,
        );
      },
    );

    test('removes only duplicated screenshot-boundary messages', () {
      final result = const BoundaryOverlapDetector().removeDuplicates([
        ExtractedScreenshot(
          sourceIndex: 0,
          regions: [
            _region(text: 'One'),
            _region(text: 'Overlap 😊'),
          ],
        ),
        ExtractedScreenshot(
          sourceIndex: 1,
          regions: [
            _region(text: 'Overlap 😊'),
            _region(text: 'Three'),
          ],
        ),
      ]);

      expect(result.removedCount, 1);
      expect(result.regions.map((region) => region.text), [
        'One',
        'Overlap 😊',
        'Three',
      ]);
    });
  });
}

CandidateMessageRegion _region({
  String text = 'Synthetic message',
  double left = 10,
  double right = 150,
  DateTime? timestamp,
}) {
  return CandidateMessageRegion(
    text: text,
    bounds: OcrBounds(left: left, top: 10, right: right, bottom: 40),
    confidence: 0.95,
    sourceIndex: 0,
    sourceOrder: 0,
    speaker: MessageSpeaker.unknown,
    timestamp: timestamp,
  );
}
