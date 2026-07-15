import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';

abstract interface class SpeakerAssignmentStrategy {
  MessageSpeaker assign(
    CandidateMessageRegion region, {
    required int pageWidth,
  });
}

class GeometrySpeakerAssignment implements SpeakerAssignmentStrategy {
  const GeometrySpeakerAssignment({
    this.edgeTolerance = 0.14,
    this.oppositeMargin = 0.2,
  });

  final double edgeTolerance;
  final double oppositeMargin;

  @override
  MessageSpeaker assign(
    CandidateMessageRegion region, {
    required int pageWidth,
  }) {
    if (pageWidth <= 0) return MessageSpeaker.unknown;
    final leftMargin = region.bounds.left / pageWidth;
    final rightMargin = (pageWidth - region.bounds.right) / pageWidth;
    if (leftMargin <= edgeTolerance && rightMargin >= oppositeMargin) {
      return MessageSpeaker.other;
    }
    if (rightMargin <= edgeTolerance && leftMargin >= oppositeMargin) {
      return MessageSpeaker.me;
    }

    final center = region.bounds.centerX / pageWidth;
    final width = region.bounds.width / pageWidth;
    if (width <= 0.62 && center <= 0.38) return MessageSpeaker.other;
    if (width <= 0.62 && center >= 0.62) return MessageSpeaker.me;
    return MessageSpeaker.unknown;
  }
}
