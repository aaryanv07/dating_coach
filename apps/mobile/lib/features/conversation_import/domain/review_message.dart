import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:flutter/foundation.dart';

const _unsetReviewField = Object();

enum MessageSpeaker { me, other, system, unknown }

extension MessageSpeakerLabel on MessageSpeaker {
  String get label => switch (this) {
    MessageSpeaker.me => 'Me',
    MessageSpeaker.other => 'Other person',
    MessageSpeaker.system => 'System',
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
    this.eventType = ConversationEventType.textMessage,
    this.classificationConfidence,
    this.speakerConfidence,
    this.timestampConfidence,
    this.relationshipConfidence,
    this.requiresReview = false,
    this.sourceRegionId,
    this.metadata = const {},
    this.relationships = const [],
    this.deletedAt,
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
  final ConversationEventType eventType;
  final double? classificationConfidence;
  final double? speakerConfidence;
  final double? timestampConfidence;
  final double? relationshipConfidence;
  final bool requiresReview;
  final String? sourceRegionId;
  final Map<String, Object?> metadata;
  final List<ConversationEventRelationship> relationships;
  final DateTime? deletedAt;

  bool get isDeleted => status == ReviewMessageStatus.deleted;
  bool get countsAsMessage => !isDeleted && eventType.countsAsMessage;
  bool get isUnknownEvent => eventType == ConversationEventType.unknown;
  String? get relationshipTargetId =>
      relationships.isEmpty ? null : relationships.first.targetEventId;

  bool get needsReview =>
      !isDeleted &&
      (requiresReview ||
          isUnknownEvent ||
          (eventType.supportsRelationship && relationships.isEmpty) ||
          (eventType.isStructural && speaker != MessageSpeaker.system) ||
          (speaker == MessageSpeaker.unknown && !eventType.isStructural) ||
          (status == ReviewMessageStatus.extracted &&
              ((ocrConfidence != null && ocrConfidence! < 0.8) ||
                  (classificationConfidence != null &&
                      classificationConfidence! < 0.75))));

  ReviewMessage copyWith({
    MessageSpeaker? speaker,
    String? text,
    Object? timestamp = _unsetReviewField,
    bool? timestampEstimated,
    ReviewMessageStatus? status,
    int? sourceScreenshotIndex,
    Object? visibleTimestampText = _unsetReviewField,
    ConversationEventType? eventType,
    Object? classificationConfidence = _unsetReviewField,
    Object? speakerConfidence = _unsetReviewField,
    Object? timestampConfidence = _unsetReviewField,
    Object? relationshipConfidence = _unsetReviewField,
    bool? requiresReview,
    String? sourceRegionId,
    Map<String, Object?>? metadata,
    List<ConversationEventRelationship>? relationships,
    Object? deletedAt = _unsetReviewField,
  }) {
    return ReviewMessage(
      id: id,
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      timestamp: identical(timestamp, _unsetReviewField)
          ? this.timestamp
          : timestamp as DateTime?,
      timestampEstimated: timestampEstimated ?? this.timestampEstimated,
      ocrConfidence: ocrConfidence,
      sourceScreenshotIndex:
          sourceScreenshotIndex ?? this.sourceScreenshotIndex,
      status: status ?? this.status,
      visibleTimestampText: identical(visibleTimestampText, _unsetReviewField)
          ? this.visibleTimestampText
          : visibleTimestampText as String?,
      eventType: eventType ?? this.eventType,
      classificationConfidence:
          identical(classificationConfidence, _unsetReviewField)
          ? this.classificationConfidence
          : classificationConfidence as double?,
      speakerConfidence: identical(speakerConfidence, _unsetReviewField)
          ? this.speakerConfidence
          : speakerConfidence as double?,
      timestampConfidence: identical(timestampConfidence, _unsetReviewField)
          ? this.timestampConfidence
          : timestampConfidence as double?,
      relationshipConfidence:
          identical(relationshipConfidence, _unsetReviewField)
          ? this.relationshipConfidence
          : relationshipConfidence as double?,
      requiresReview: requiresReview ?? this.requiresReview,
      sourceRegionId: sourceRegionId ?? this.sourceRegionId,
      metadata: metadata ?? this.metadata,
      relationships: relationships ?? this.relationships,
      deletedAt: identical(deletedAt, _unsetReviewField)
          ? this.deletedAt
          : deletedAt as DateTime?,
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
