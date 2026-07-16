import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

abstract interface class ConversationEventClassificationStrategy {
  List<ReviewMessage> classify(List<CandidateMessageRegion> regions);
}

/// Replaceable, deterministic classification rules for Phase 6A.1.
///
/// Confidence values describe rule evidence only. They are not production
/// accuracy claims and low-evidence output remains explicitly reviewable.
class DeterministicConversationEventClassifier
    implements ConversationEventClassificationStrategy {
  const DeterministicConversationEventClassifier();

  @override
  List<ReviewMessage> classify(List<CandidateMessageRegion> regions) {
    final events = <ReviewMessage>[];
    final eventRegions = <CandidateMessageRegion>[];
    for (final region in regions) {
      final id =
          'ocr-${region.sourceIndex}-${region.sourceOrder}-${events.length}';
      final rule = _classify(region, eventRegions);
      final previousTargetIndex = rule.isReaction
          ? _nearestTargetIndex(region, eventRegions)
          : null;
      final target = previousTargetIndex == null
          ? null
          : events[previousTargetIndex];
      final relationship = target == null
          ? const <ConversationEventRelationship>[]
          : [
              ConversationEventRelationship(
                id: 'relationship-$id-${target.id}',
                sourceEventId: id,
                targetEventId: target.id,
                type: ConversationEventRelationshipType.reactionTarget,
                confidence: rule.relationshipConfidence,
              ),
            ];
      final speaker = rule.type.isStructural
          ? MessageSpeaker.system
          : rule.isReaction
          ? MessageSpeaker.unknown
          : region.speaker;
      final requiresReview =
          rule.type == ConversationEventType.unknown ||
          (speaker == MessageSpeaker.unknown && !rule.type.isStructural) ||
          region.confidence == null ||
          rule.confidence < 0.75 ||
          (rule.isReaction && target == null);
      events.add(
        ReviewMessage(
          id: id,
          speaker: speaker,
          text: region.text,
          timestamp: region.timestamp,
          timestampEstimated: false,
          ocrConfidence: region.confidence,
          sourceScreenshotIndex: region.sourceIndex,
          status: ReviewMessageStatus.extracted,
          visibleTimestampText: region.visibleTimestampText,
          eventType: rule.type,
          classificationConfidence: rule.confidence,
          speakerConfidence: speaker == MessageSpeaker.system
              ? 1
              : speaker == MessageSpeaker.unknown
              ? null
              : 0.9,
          timestampConfidence:
              region.timestamp != null && region.visibleTimestampText != null
              ? 0.9
              : null,
          relationshipConfidence: rule.relationshipConfidence,
          requiresReview: requiresReview,
          sourceRegionId: 'region-${region.sourceIndex}-${region.sourceOrder}',
          metadata: {
            'classification_strategy': 'deterministic_rules_v1',
            if (rule.isReaction) 'reaction': region.text,
          },
          relationships: relationship,
        ),
      );
      eventRegions.add(region);
    }
    return List.unmodifiable(events);
  }

  _Classification _classify(
    CandidateMessageRegion region,
    List<CandidateMessageRegion> previous,
  ) {
    if (region.eventTypeHint != null) {
      return _Classification(region.eventTypeHint!, 0.99);
    }
    final normalized = region.text.trim().toLowerCase();
    if (_looksLikeEmojiOnly(region.text)) {
      final target = _nearestTargetIndex(region, previous);
      if (target != null) {
        return const _Classification(
          ConversationEventType.reaction,
          0.88,
          relationshipConfidence: 0.86,
        );
      }
      return const _Classification(ConversationEventType.emojiMessage, 0.9);
    }
    if (_deletedMarkers.contains(normalized)) {
      return const _Classification(ConversationEventType.deletedMessage, 0.98);
    }
    if (normalized == 'new messages' ||
        RegExp(r'^\d+\s+unread messages?$').hasMatch(normalized)) {
      return const _Classification(ConversationEventType.unreadSeparator, 0.98);
    }
    if (normalized.contains('end-to-end encrypted') ||
        normalized.contains('security code changed')) {
      return const _Classification(
        ConversationEventType.encryptionNotice,
        0.96,
      );
    }
    if (normalized == 'missed voice call' ||
        normalized == 'missed video call') {
      return const _Classification(ConversationEventType.missedCall, 0.97);
    }
    if (normalized == 'declined voice call' ||
        normalized == 'declined video call') {
      return const _Classification(ConversationEventType.declinedCall, 0.97);
    }
    if (normalized == 'voice call ended' || normalized == 'video call ended') {
      return const _Classification(ConversationEventType.callEnded, 0.96);
    }
    if (normalized == 'voice call started' ||
        normalized == 'video call started') {
      return const _Classification(ConversationEventType.callStarted, 0.96);
    }
    if (normalized == 'photo' || normalized == 'image') {
      return const _Classification(ConversationEventType.image, 0.9);
    }
    if (normalized == 'gif') {
      return const _Classification(ConversationEventType.gif, 0.95);
    }
    if (normalized == 'sticker') {
      return const _Classification(ConversationEventType.sticker, 0.95);
    }
    if (RegExp(
      r'^voice (message|note)(\s+\d{1,2}:\d{2})?$',
    ).hasMatch(normalized)) {
      return const _Classification(ConversationEventType.voiceNote, 0.93);
    }
    if (RegExp(r'^https?://\S+$').hasMatch(normalized)) {
      return const _Classification(ConversationEventType.link, 0.95);
    }
    if (normalized == 'this message was edited' || normalized == 'edited') {
      return const _Classification(
        ConversationEventType.editedMessageMarker,
        0.85,
      );
    }
    return const _Classification(ConversationEventType.textMessage, 0.82);
  }

  int? _nearestTargetIndex(
    CandidateMessageRegion current,
    List<CandidateMessageRegion> previous,
  ) {
    if (previous.isEmpty) return null;
    if (current.compactAttachmentHint == false) return null;
    for (var index = previous.length - 1; index >= 0; index--) {
      final target = previous[index];
      if (target.eventTypeHint?.isStructural ?? false) continue;
      if (target.sourceIndex != current.sourceIndex) return null;
      if (current.compactAttachmentHint == true) return index;
      final horizontallyNear =
          current.bounds.centerX >= target.bounds.left - current.bounds.width &&
          current.bounds.centerX <= target.bounds.right + current.bounds.width;
      final verticalGap = (current.bounds.centerY - target.bounds.bottom).abs();
      final maximumGap = target.bounds.height.clamp(20, 56);
      final compact =
          current.bounds.width <= target.bounds.width * 0.45 &&
          current.bounds.height <= target.bounds.height * 0.9;
      if (horizontallyNear && compact && verticalGap <= maximumGap) {
        return index;
      }
      return null;
    }
    return null;
  }

  bool _looksLikeEmojiOnly(String text) {
    final clean = text.replaceAll(RegExp(r'[\s\uFE0E\uFE0F\u200D]'), '');
    if (clean.isEmpty) return false;
    for (final rune in clean.runes) {
      final emoji =
          (rune >= 0x1F000 && rune <= 0x1FAFF) ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          (rune >= 0x1F3FB && rune <= 0x1F3FF) ||
          rune == 0x20E3 ||
          rune == 0x00A9 ||
          rune == 0x00AE ||
          rune == 0x203C ||
          rune == 0x2049 ||
          rune == 0x2122 ||
          rune == 0x2139;
      if (!emoji) return false;
    }
    return true;
  }

  static const _deletedMarkers = {
    'this message was deleted',
    'you deleted this message',
    'message deleted',
  };
}

class _Classification {
  const _Classification(
    this.type,
    this.confidence, {
    this.relationshipConfidence,
  });

  final ConversationEventType type;
  final double confidence;
  final double? relationshipConfidence;

  bool get isReaction => type == ConversationEventType.reaction;
}
