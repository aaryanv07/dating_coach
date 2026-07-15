import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversation_import/domain/timestamp_parser.dart';

abstract interface class MessageRegionGroupingStrategy {
  List<CandidateMessageRegion> group(
    RecognizedTextPage page, {
    required String locale,
  });
}

class GeometryMessageRegionGrouper implements MessageRegionGroupingStrategy {
  const GeometryMessageRegionGrouper({
    this.timestampParser = const LocaleAwareTimestampParser(),
  });

  final ConversationTimestampParser timestampParser;

  @override
  List<CandidateMessageRegion> group(
    RecognizedTextPage page, {
    required String locale,
  }) {
    final sorted = [...page.lines]
      ..sort((a, b) {
        final vertical = a.bounds.top.compareTo(b.bounds.top);
        return vertical != 0
            ? vertical
            : a.bounds.left.compareTo(b.bounds.left);
      });
    final output = <CandidateMessageRegion>[];
    final current = <RecognizedLine>[];
    ParsedTimestamp? dateContext;
    ParsedTimestamp? pendingTimestamp;
    ParsedTimestamp? currentTimestamp;

    void flush() {
      if (current.isEmpty) return;
      var text = current.map((line) => line.text.trim()).join(' ');
      final trailing = timestampParser.extractTrailing(text, locale: locale);
      if (trailing != null) {
        text = trailing.messageText;
        currentTimestamp = trailing.timestamp;
      }
      if (text.isNotEmpty) {
        final bounds = current
            .skip(1)
            .fold(
              current.first.bounds,
              (value, line) => value.union(line.bounds),
            );
        output.add(
          CandidateMessageRegion(
            text: text,
            bounds: bounds,
            confidence: _averageConfidence(current),
            sourceIndex: page.sourceIndex,
            sourceOrder: output.length,
            speaker: MessageSpeaker.unknown,
            timestamp: resolveVisibleTimestamp(
              dateContext: dateContext,
              timestamp: currentTimestamp,
            ),
            visibleTimestampText: currentTimestamp?.rawText,
          ),
        );
      }
      current.clear();
      currentTimestamp = null;
    }

    for (final line in sorted) {
      final cleanText = line.text.trim();
      if (cleanText.isEmpty) continue;
      final timestamp = timestampParser.parse(cleanText, locale: locale);
      if (timestamp != null) {
        if (timestamp.precision == TimestampPrecision.date ||
            timestamp.precision == TimestampPrecision.dateTime) {
          flush();
          dateContext = timestamp;
          pendingTimestamp = null;
        } else if (current.isNotEmpty) {
          currentTimestamp = timestamp;
          flush();
        } else {
          pendingTimestamp = timestamp;
        }
        continue;
      }

      if (current.isNotEmpty && !_belongsWith(current.last, line, page.width)) {
        flush();
      }
      if (current.isEmpty && pendingTimestamp != null) {
        currentTimestamp = pendingTimestamp;
        pendingTimestamp = null;
      }
      current.add(line);
    }
    flush();
    return output;
  }

  bool _belongsWith(RecognizedLine previous, RecognizedLine next, int width) {
    final verticalGap = next.bounds.top - previous.bounds.bottom;
    final maximumGap = (previous.bounds.height + next.bounds.height) * 0.75;
    if (verticalGap < -2 || verticalGap > maximumGap.clamp(12, 48)) {
      return false;
    }
    final centerDistance = (previous.bounds.centerX - next.bounds.centerX)
        .abs();
    final horizontalOverlap =
        (previous.bounds.right < next.bounds.right
            ? previous.bounds.right
            : next.bounds.right) -
        (previous.bounds.left > next.bounds.left
            ? previous.bounds.left
            : next.bounds.left);
    return horizontalOverlap > 0 || centerDistance <= width * 0.12;
  }

  double? _averageConfidence(List<RecognizedLine> lines) {
    var weightedTotal = 0.0;
    var weight = 0;
    for (final line in lines) {
      final lineConfidence = line.confidence ?? _elementConfidence(line);
      if (lineConfidence == null) continue;
      final lineWeight = line.text.runes.length.clamp(1, 1000);
      weightedTotal += lineConfidence * lineWeight;
      weight += lineWeight;
    }
    return weight == 0 ? null : (weightedTotal / weight).clamp(0, 1);
  }

  double? _elementConfidence(RecognizedLine line) {
    final values = line.elements
        .map((element) => element.confidence)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
