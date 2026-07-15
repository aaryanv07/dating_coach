import 'package:flutter/foundation.dart';

enum MessageSpeaker { me, other, unknown }

extension MessageSpeakerLabel on MessageSpeaker {
  String get label => switch (this) {
    MessageSpeaker.me => 'Me',
    MessageSpeaker.other => 'Other person',
    MessageSpeaker.unknown => 'Unassigned',
  };
}

enum ReviewMessageStatus { extracted, edited, added, deleted, confirmed }

@immutable
class ReviewMessage {
  const ReviewMessage({
    required this.id,
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.timestampEstimated,
    required this.ocrConfidence,
    required this.sourceScreenshotIndex,
    required this.status,
    this.visibleTimestampText,
  });

  final String id;
  final MessageSpeaker speaker;
  final String text;
  final DateTime? timestamp;
  final bool timestampEstimated;
  final double? ocrConfidence;
  final int? sourceScreenshotIndex;
  final ReviewMessageStatus status;
  final String? visibleTimestampText;

  bool get isDeleted => status == ReviewMessageStatus.deleted;

  bool get needsReview =>
      !isDeleted &&
      ocrConfidence != null &&
      ocrConfidence! < 0.8 &&
      status == ReviewMessageStatus.extracted;

  ReviewMessage copyWith({
    MessageSpeaker? speaker,
    String? text,
    bool? timestampEstimated,
    ReviewMessageStatus? status,
    int? sourceScreenshotIndex,
    String? visibleTimestampText,
  }) {
    return ReviewMessage(
      id: id,
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      timestamp: timestamp,
      timestampEstimated: timestampEstimated ?? this.timestampEstimated,
      ocrConfidence: ocrConfidence,
      sourceScreenshotIndex:
          sourceScreenshotIndex ?? this.sourceScreenshotIndex,
      status: status ?? this.status,
      visibleTimestampText: visibleTimestampText ?? this.visibleTimestampText,
    );
  }
}

@immutable
class ImportSourceMetadata {
  const ImportSourceMetadata({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.byteSize,
    required this.index,
  });

  final String id;
  final String name;
  final String mimeType;
  final int byteSize;
  final int index;
}
