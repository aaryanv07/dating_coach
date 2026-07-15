import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/foundation.dart';

@immutable
class OcrBounds {
  const OcrBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;

  OcrBounds union(OcrBounds other) => OcrBounds(
    left: left < other.left ? left : other.left,
    top: top < other.top ? top : other.top,
    right: right > other.right ? right : other.right,
    bottom: bottom > other.bottom ? bottom : other.bottom,
  );
}

@immutable
class RecognizedElement {
  const RecognizedElement({
    required this.text,
    required this.bounds,
    required this.confidence,
  });

  final String text;
  final OcrBounds bounds;
  final double? confidence;
}

@immutable
class RecognizedLine {
  const RecognizedLine({
    required this.text,
    required this.bounds,
    required this.confidence,
    this.elements = const [],
  });

  final String text;
  final OcrBounds bounds;
  final double? confidence;
  final List<RecognizedElement> elements;
}

@immutable
class RecognizedTextPage {
  const RecognizedTextPage({
    required this.sourceIndex,
    required this.width,
    required this.height,
    required this.lines,
  });

  final int sourceIndex;
  final int width;
  final int height;
  final List<RecognizedLine> lines;
}

@immutable
class PreprocessedImage {
  const PreprocessedImage({
    required this.sourceIndex,
    required this.bytes,
    required this.width,
    required this.height,
    required this.orientationCorrected,
    required this.wasResized,
  });

  final int sourceIndex;
  final Uint8List bytes;
  final int width;
  final int height;
  final bool orientationCorrected;
  final bool wasResized;
}

enum TimestampPrecision { date, time, dateTime }

@immutable
class ParsedTimestamp {
  const ParsedTimestamp({
    required this.rawText,
    required this.precision,
    this.value,
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
  });

  final String rawText;
  final TimestampPrecision precision;
  final DateTime? value;
  final int? year;
  final int? month;
  final int? day;
  final int? hour;
  final int? minute;
}

@immutable
class CandidateMessageRegion {
  const CandidateMessageRegion({
    required this.text,
    required this.bounds,
    required this.confidence,
    required this.sourceIndex,
    required this.sourceOrder,
    required this.speaker,
    this.timestamp,
    this.visibleTimestampText,
  });

  final String text;
  final OcrBounds bounds;
  final double? confidence;
  final int sourceIndex;
  final int sourceOrder;
  final MessageSpeaker speaker;
  final DateTime? timestamp;
  final String? visibleTimestampText;

  CandidateMessageRegion copyWith({
    MessageSpeaker? speaker,
    DateTime? timestamp,
    String? visibleTimestampText,
  }) {
    return CandidateMessageRegion(
      text: text,
      bounds: bounds,
      confidence: confidence,
      sourceIndex: sourceIndex,
      sourceOrder: sourceOrder,
      speaker: speaker ?? this.speaker,
      timestamp: timestamp ?? this.timestamp,
      visibleTimestampText: visibleTimestampText ?? this.visibleTimestampText,
    );
  }
}

enum ExtractionWarningCode {
  confidenceUnavailable,
  screenshotOrderAdjusted,
  screenshotOrderUncertain,
  timelineGap,
  duplicateOverlapRemoved,
  unknownSpeaker,
}

@immutable
class ExtractionWarning {
  const ExtractionWarning({required this.code, required this.message});

  final ExtractionWarningCode code;
  final String message;
}

@immutable
class ExtractionMetadata {
  const ExtractionMetadata({
    required this.provider,
    required this.providerVersion,
    required this.extractionVersion,
    required this.preprocessingVersion,
    required this.confidenceAvailable,
  });

  final String provider;
  final String providerVersion;
  final String extractionVersion;
  final String preprocessingVersion;
  final bool confidenceAvailable;
}

@immutable
class OcrExtractionResult {
  const OcrExtractionResult({
    required this.messages,
    required this.warnings,
    required this.metadata,
  });

  final List<ReviewMessage> messages;
  final List<ExtractionWarning> warnings;
  final ExtractionMetadata metadata;
}

class ExtractionCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  void throwIfCancelled() {
    if (_isCancelled) throw const ExtractionCancelledException();
  }
}

class ExtractionException implements Exception {
  const ExtractionException(this.safeMessage);

  final String safeMessage;

  @override
  String toString() => 'ExtractionException($safeMessage)';
}

class TransientExtractionException extends ExtractionException {
  const TransientExtractionException(super.safeMessage);
}

class ExtractionCancelledException extends ExtractionException {
  const ExtractionCancelledException() : super('Extraction was cancelled.');
}
