import 'dart:math' as math;

import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

import 'fixture_models.dart';

class BenchmarkCorrectionCounts {
  const BenchmarkCorrectionCounts({
    required this.text,
    required this.speaker,
    required this.timestamp,
    required this.missing,
    required this.extra,
    required this.order,
  });

  final int text;
  final int speaker;
  final int timestamp;
  final int missing;
  final int extra;
  final int order;

  int get total => text + speaker + timestamp + missing + extra + order;

  Map<String, Object> toJson() => {
    'text': text,
    'speaker': speaker,
    'timestamp': timestamp,
    'missing': missing,
    'extra': extra,
    'order': order,
    'total': total,
  };
}

class BenchmarkMetrics {
  const BenchmarkMetrics({
    required this.characterAccuracy,
    required this.wordAccuracy,
    required this.messageExtractionAccuracy,
    required this.eventClassificationAccuracy,
    required this.speakerAssignmentAccuracy,
    required this.timestampAccuracy,
    required this.duplicateRemovalAccuracy,
    required this.orderingAccuracy,
    required this.warningAccuracy,
    required this.manualReviewRate,
    required this.reviewRecall,
    required this.reviewPrecision,
    required this.corrections,
  });

  final double characterAccuracy;
  final double wordAccuracy;
  final double messageExtractionAccuracy;
  final double eventClassificationAccuracy;
  final double speakerAssignmentAccuracy;
  final double timestampAccuracy;
  final double duplicateRemovalAccuracy;
  final double orderingAccuracy;
  final double warningAccuracy;
  final double manualReviewRate;
  final double reviewRecall;
  final double reviewPrecision;
  final BenchmarkCorrectionCounts corrections;

  Map<String, Object> toJson() => {
    'character_accuracy': characterAccuracy,
    'word_accuracy': wordAccuracy,
    'message_extraction_accuracy': messageExtractionAccuracy,
    'event_classification_accuracy': eventClassificationAccuracy,
    'speaker_assignment_accuracy': speakerAssignmentAccuracy,
    'timestamp_accuracy': timestampAccuracy,
    'duplicate_removal_accuracy': duplicateRemovalAccuracy,
    'ordering_accuracy': orderingAccuracy,
    'warning_accuracy': warningAccuracy,
    'manual_review_rate': manualReviewRate,
    'review_recall': reviewRecall,
    'review_precision': reviewPrecision,
    'corrections': corrections.toJson(),
  };
}

class ExtractionBenchmarkEvaluator {
  const ExtractionBenchmarkEvaluator();

  BenchmarkMetrics evaluate(
    BenchmarkFixture fixture,
    OcrExtractionResult actual,
  ) {
    final expectedMessages = fixture.messages;
    final actualMessages = actual.messages
        .where((message) => !message.isDeleted)
        .toList(growable: false);
    final expectedText = expectedMessages
        .map((message) => message.text)
        .join('\n');
    final actualText = actualMessages.map((message) => message.text).join('\n');
    final alignment = _align(expectedMessages, actualMessages);
    final matched = alignment
        .where(
          (pair) =>
              pair.expectedIndex != null &&
              pair.actualIndex != null &&
              _textSimilarity(
                    expectedMessages[pair.expectedIndex!].text,
                    actualMessages[pair.actualIndex!].text,
                  ) >=
                  0.55,
        )
        .toList(growable: false);
    final expectedCount = expectedMessages.length;
    final actualCount = actualMessages.length;
    final denominator = math.max(expectedCount, actualCount);

    var correctSpeakers = 0;
    var correctTimestamps = 0;
    var textCorrections = 0;
    var speakerCorrections = 0;
    var timestampCorrections = 0;
    var reviewTruePositives = 0;
    for (final pair in matched) {
      final expected = expectedMessages[pair.expectedIndex!];
      final found = actualMessages[pair.actualIndex!];
      if (_normalizedText(expected.text) == _normalizedText(found.text)) {
        // Exact normalized content needs no Review Studio text correction.
      } else {
        textCorrections++;
      }
      if (expected.speaker == found.speaker) {
        correctSpeakers++;
      } else {
        speakerCorrections++;
      }
      if (_sameTimestamp(expected.timestamp, found.timestamp)) {
        correctTimestamps++;
      } else {
        timestampCorrections++;
      }
      if (expected.requiresManualReview &&
          _requiresManualReview(found, actual.metadata.confidenceAvailable)) {
        reviewTruePositives++;
      }
    }
    final missing = expectedCount - matched.length;
    final extra = actualCount - matched.length;
    final expectedReviewCount = expectedMessages
        .where((message) => message.requiresManualReview)
        .length;
    final actualReviewCount = actualMessages
        .where(
          (message) => _requiresManualReview(
            message,
            actual.metadata.confidenceAvailable,
          ),
        )
        .length;
    final expectedWarnings = {...fixture.expectedWarnings};
    if (!actual.metadata.confidenceAvailable) {
      expectedWarnings.add(ExtractionWarningCode.confidenceUnavailable);
    }
    final actualWarnings = actual.warnings
        .map((warning) => warning.code)
        .toSet();
    final warningUnion = {...expectedWarnings, ...actualWarnings};
    final warningIntersection = expectedWarnings.intersection(actualWarnings);
    final expectedMessageOrder = expectedMessages
        .map((message) => _normalizedText(message.text))
        .toList(growable: false);
    final actualMessageOrder = actualMessages
        .map((message) => _normalizedText(message.text))
        .toList(growable: false);
    final expectedEventKeys = <String>[
      for (final message in fixture.messages)
        _eventKey(message.eventType.wireName, message.text),
      for (final event in fixture.events)
        _eventKey(event.eventType.wireName, event.text),
      for (final page in fixture.pages)
        if (page.dateLabel case final label?)
          _eventKey('date_separator', label),
      for (final page in fixture.pages)
        for (final reaction in page.reactions)
          if (reaction.recognizeAsText) _eventKey('reaction', reaction.text),
    ];
    final actualEventKeys = actual.events
        .where((event) => !event.isDeleted)
        .map((event) => _eventKey(event.eventType.wireName, event.text))
        .toList(growable: false);

    return BenchmarkMetrics(
      characterAccuracy: _sequenceAccuracy(
        _normalizedText(expectedText).runes.toList(),
        _normalizedText(actualText).runes.toList(),
      ),
      wordAccuracy: _sequenceAccuracy(
        _wordTokens(expectedText),
        _wordTokens(actualText),
      ),
      messageExtractionAccuracy: denominator == 0
          ? 1
          : matched.length / denominator,
      eventClassificationAccuracy: _multisetAccuracy(
        expectedEventKeys,
        actualEventKeys,
      ),
      speakerAssignmentAccuracy: expectedCount == 0
          ? 1
          : correctSpeakers / expectedCount,
      timestampAccuracy: expectedCount == 0
          ? 1
          : correctTimestamps / expectedCount,
      duplicateRemovalAccuracy: _countAccuracy(
        fixture.expectedDuplicateIds.length,
        actual.diagnostics.duplicateMessagesRemoved,
      ),
      orderingAccuracy: _sequenceAccuracy(
        fixture.expectedSourceOrder,
        actual.diagnostics.orderedSourceIndices,
      ),
      warningAccuracy: warningUnion.isEmpty
          ? 1
          : warningIntersection.length / warningUnion.length,
      manualReviewRate: actualCount == 0 ? 0 : actualReviewCount / actualCount,
      reviewRecall: expectedReviewCount == 0
          ? 1
          : reviewTruePositives / expectedReviewCount,
      reviewPrecision: actualReviewCount == 0
          ? (expectedReviewCount == 0 ? 1 : 0)
          : reviewTruePositives / actualReviewCount,
      corrections: BenchmarkCorrectionCounts(
        text: textCorrections,
        speaker: speakerCorrections,
        timestamp: timestampCorrections,
        missing: missing,
        extra: extra,
        order: _editDistance(expectedMessageOrder, actualMessageOrder),
      ),
    );
  }

  List<_AlignmentPair> _align(
    List<BenchmarkExpectedMessage> expected,
    List<ReviewMessage> actual,
  ) {
    final scores = List.generate(
      expected.length + 1,
      (_) => List<double>.filled(actual.length + 1, 0),
    );
    for (var row = 1; row <= expected.length; row++) {
      for (var column = 1; column <= actual.length; column++) {
        final similarity = _textSimilarity(
          expected[row - 1].text,
          actual[column - 1].text,
        );
        final match = similarity >= 0.35
            ? scores[row - 1][column - 1] + similarity
            : double.negativeInfinity;
        scores[row][column] = math.max(
          match,
          math.max(scores[row - 1][column], scores[row][column - 1]),
        );
      }
    }
    final reversed = <_AlignmentPair>[];
    var row = expected.length;
    var column = actual.length;
    while (row > 0 || column > 0) {
      if (row > 0 && column > 0) {
        final similarity = _textSimilarity(
          expected[row - 1].text,
          actual[column - 1].text,
        );
        if (similarity >= 0.35 &&
            (scores[row][column] - (scores[row - 1][column - 1] + similarity))
                    .abs() <
                0.000001) {
          reversed.add(
            _AlignmentPair(expectedIndex: row - 1, actualIndex: column - 1),
          );
          row--;
          column--;
          continue;
        }
      }
      if (row > 0 &&
          (column == 0 || scores[row - 1][column] >= scores[row][column - 1])) {
        reversed.add(_AlignmentPair(expectedIndex: row - 1));
        row--;
      } else {
        reversed.add(_AlignmentPair(actualIndex: column - 1));
        column--;
      }
    }
    return reversed.reversed.toList(growable: false);
  }

  bool _requiresManualReview(ReviewMessage message, bool confidenceAvailable) {
    return !confidenceAvailable ||
        message.needsReview ||
        message.speaker == MessageSpeaker.unknown ||
        message.text.trim().isEmpty;
  }

  bool _sameTimestamp(DateTime? expected, DateTime? actual) {
    if (expected == null || actual == null) return expected == actual;
    return expected.year == actual.year &&
        expected.month == actual.month &&
        expected.day == actual.day &&
        expected.hour == actual.hour &&
        expected.minute == actual.minute;
  }

  double _textSimilarity(String first, String second) {
    final firstRunes = _normalizedText(first).runes.toList();
    final secondRunes = _normalizedText(second).runes.toList();
    return _sequenceAccuracy(firstRunes, secondRunes);
  }

  double _countAccuracy(int expected, int actual) {
    if (expected == 0 && actual == 0) return 1;
    final denominator = math.max(expected, actual);
    return (1 - (expected - actual).abs() / denominator).clamp(0, 1);
  }
}

String _eventKey(String eventType, String text) =>
    '$eventType|${_normalizedText(text)}';

double _multisetAccuracy(List<String> expected, List<String> actual) {
  if (expected.isEmpty && actual.isEmpty) return 1;
  final expectedCounts = <String, int>{};
  final actualCounts = <String, int>{};
  for (final value in expected) {
    expectedCounts[value] = (expectedCounts[value] ?? 0) + 1;
  }
  for (final value in actual) {
    actualCounts[value] = (actualCounts[value] ?? 0) + 1;
  }
  var matches = 0;
  for (final entry in expectedCounts.entries) {
    matches += math.min(entry.value, actualCounts[entry.key] ?? 0);
  }
  return matches / math.max(expected.length, actual.length);
}

class _AlignmentPair {
  const _AlignmentPair({this.expectedIndex, this.actualIndex});

  final int? expectedIndex;
  final int? actualIndex;
}

String _normalizedText(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

List<String> _wordTokens(String text) {
  final normalized = _normalizedText(text);
  return normalized.isEmpty ? const [] : normalized.split(' ');
}

double _sequenceAccuracy<T>(List<T> expected, List<T> actual) {
  if (expected.isEmpty && actual.isEmpty) return 1;
  final denominator = math.max(expected.length, actual.length);
  return (1 - _editDistance(expected, actual) / denominator).clamp(0, 1);
}

int _editDistance<T>(List<T> first, List<T> second) {
  if (first.isEmpty) return second.length;
  if (second.isEmpty) return first.length;
  var previous = List<int>.generate(second.length + 1, (index) => index);
  for (var row = 1; row <= first.length; row++) {
    final current = List<int>.filled(second.length + 1, 0)..[0] = row;
    for (var column = 1; column <= second.length; column++) {
      final substitution =
          previous[column - 1] + (first[row - 1] == second[column - 1] ? 0 : 1);
      current[column] = math.min(
        substitution,
        math.min(previous[column] + 1, current[column - 1] + 1),
      );
    }
    previous = current;
  }
  return previous.last;
}
