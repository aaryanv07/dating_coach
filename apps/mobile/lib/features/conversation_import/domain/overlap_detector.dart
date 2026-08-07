import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/screenshot_ordering.dart';

class OverlapDetectionResult {
  const OverlapDetectionResult({
    required this.regions,
    required this.removedCount,
  });

  final List<CandidateMessageRegion> regions;
  final int removedCount;
}

abstract interface class ScreenshotOverlapStrategy {
  OverlapDetectionResult removeDuplicates(
    List<ExtractedScreenshot> screenshots,
  );
}

class BoundaryOverlapDetector implements ScreenshotOverlapStrategy {
  const BoundaryOverlapDetector({this.maximumWindow = 12});

  final int maximumWindow;

  @override
  OverlapDetectionResult removeDuplicates(
    List<ExtractedScreenshot> screenshots,
  ) {
    final output = <CandidateMessageRegion>[];
    var removed = 0;
    for (final screenshot in screenshots) {
      var start = 0;
      final maximum = [
        maximumWindow,
        output.length,
        screenshot.regions.length,
      ].reduce((a, b) => a < b ? a : b);
      for (var size = maximum; size > 0; size--) {
        var matches = true;
        for (var offset = 0; offset < size; offset++) {
          final existing = output[output.length - size + offset];
          final incoming = screenshot.regions[offset];
          if (!_sameMessage(existing, incoming)) {
            matches = false;
            break;
          }
        }
        if (matches) {
          start = size;
          removed += size;
          break;
        }
      }
      output.addAll(screenshot.regions.skip(start));
    }
    return OverlapDetectionResult(
      regions: List.unmodifiable(output),
      removedCount: removed,
    );
  }

  bool _sameMessage(
    CandidateMessageRegion first,
    CandidateMessageRegion second,
  ) {
    if (first.eventTypeHint != second.eventTypeHint ||
        (first.compactAttachmentHint != null &&
            second.compactAttachmentHint != null &&
            first.compactAttachmentHint != second.compactAttachmentHint)) {
      return false;
    }
    if (first.speaker != second.speaker &&
        first.speaker.name != 'unknown' &&
        second.speaker.name != 'unknown') {
      return false;
    }
    return _normalize(first.text) == _normalize(second.text);
  }

  String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
