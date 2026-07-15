import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';

class ExtractedScreenshot {
  const ExtractedScreenshot({required this.sourceIndex, required this.regions});

  final int sourceIndex;
  final List<CandidateMessageRegion> regions;

  DateTime? get firstTimestamp => regions
      .map((region) => region.timestamp)
      .whereType<DateTime>()
      .firstOrNull;

  DateTime? get lastTimestamp => regions
      .map((region) => region.timestamp)
      .whereType<DateTime>()
      .lastOrNull;
}

class ScreenshotOrderingResult {
  const ScreenshotOrderingResult({
    required this.screenshots,
    required this.warnings,
  });

  final List<ExtractedScreenshot> screenshots;
  final List<ExtractionWarning> warnings;
}

abstract interface class ScreenshotOrderingStrategy {
  ScreenshotOrderingResult order(List<ExtractedScreenshot> screenshots);
}

class TimestampScreenshotOrdering implements ScreenshotOrderingStrategy {
  const TimestampScreenshotOrdering({
    this.timelineGap = const Duration(hours: 12),
  });

  final Duration timelineGap;

  @override
  ScreenshotOrderingResult order(List<ExtractedScreenshot> screenshots) {
    if (screenshots.length < 2) {
      return ScreenshotOrderingResult(
        screenshots: List.unmodifiable(screenshots),
        warnings: const [],
      );
    }
    final warnings = <ExtractionWarning>[];
    var ordered = List<ExtractedScreenshot>.of(screenshots);
    final hasInternalRegression = ordered.any((screenshot) {
      final timestamps = screenshot.regions
          .map((region) => region.timestamp)
          .whereType<DateTime>()
          .toList();
      for (var index = 1; index < timestamps.length; index++) {
        if (timestamps[index].isBefore(timestamps[index - 1])) return true;
      }
      return false;
    });
    if (hasInternalRegression) {
      warnings.add(
        const ExtractionWarning(
          code: ExtractionWarningCode.screenshotOrderUncertain,
          message:
              'Visible timestamps run backward within a screenshot. Review its message order.',
        ),
      );
    }
    final hasTimestampForEveryScreenshot = ordered.every(
      (screenshot) => screenshot.firstTimestamp != null,
    );
    if (hasTimestampForEveryScreenshot) {
      final originalOrder = ordered.map((item) => item.sourceIndex).toList();
      ordered.sort((a, b) => a.firstTimestamp!.compareTo(b.firstTimestamp!));
      final adjustedOrder = ordered.map((item) => item.sourceIndex).toList();
      if (!_sameOrder(originalOrder, adjustedOrder)) {
        warnings.add(
          const ExtractionWarning(
            code: ExtractionWarningCode.screenshotOrderAdjusted,
            message:
                'Screenshot order was adjusted using visible timestamps. Review the sequence.',
          ),
        );
      }
    } else {
      warnings.add(
        const ExtractionWarning(
          code: ExtractionWarningCode.screenshotOrderUncertain,
          message:
              'Some screenshots have no complete visible timestamp. Confirm their order.',
        ),
      );
    }

    for (var index = 1; index < ordered.length; index++) {
      final previous = ordered[index - 1].lastTimestamp;
      final next = ordered[index].firstTimestamp;
      if (previous != null &&
          next != null &&
          next.difference(previous) > timelineGap) {
        warnings.add(
          ExtractionWarning(
            code: ExtractionWarningCode.timelineGap,
            message:
                'A visible timeline gap appears before screenshot ${ordered[index].sourceIndex + 1}.',
          ),
        );
      }
    }
    return ScreenshotOrderingResult(
      screenshots: List.unmodifiable(ordered),
      warnings: List.unmodifiable(warnings),
    );
  }

  bool _sameOrder(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
