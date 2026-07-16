import 'dart:math' as math;

import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/foundation.dart';

const int conversationReadinessThreshold = 85;

@immutable
class ReadinessCheck {
  const ReadinessCheck({
    required this.label,
    required this.passed,
    required this.points,
    required this.maximum,
  });

  final String label;
  final bool passed;
  final int points;
  final int maximum;
}

@immutable
class ReadinessReport {
  const ReadinessReport({required this.score, required this.checks});

  final int score;
  final List<ReadinessCheck> checks;

  bool get isReady =>
      score >= conversationReadinessThreshold &&
      checks
          .where((check) => check.label != 'Timestamp availability')
          .every((check) => check.passed);
}

abstract final class ConversationReadiness {
  static ReadinessReport evaluate(List<ReviewMessage> messages) {
    final activeEvents = messages.where((event) => !event.isDeleted).toList();
    final active = activeEvents
        .where((event) => event.eventType.countsAsMessage)
        .toList();
    final checks = <ReadinessCheck>[];

    final enoughMessages = active.length >= 2;
    checks.add(
      ReadinessCheck(
        label: 'Missing messages',
        passed: enoughMessages,
        points: enoughMessages ? 5 : 0,
        maximum: 5,
      ),
    );

    final noEmptyMessages =
        active.isNotEmpty &&
        active.every(
          (message) =>
              !{
                ConversationEventType.textMessage,
                ConversationEventType.emojiMessage,
              }.contains(message.eventType) ||
              message.text.trim().isNotEmpty,
        );
    checks.add(
      ReadinessCheck(
        label: 'Empty messages',
        passed: noEmptyMessages,
        points: noEmptyMessages ? 20 : 0,
        maximum: 20,
      ),
    );

    final speakersAssigned =
        active.isNotEmpty &&
        active.every(
          (message) =>
              message.speaker == MessageSpeaker.me ||
              message.speaker == MessageSpeaker.other,
        ) &&
        active.map((message) => message.speaker).toSet().containsAll({
          MessageSpeaker.me,
          MessageSpeaker.other,
        });
    checks.add(
      ReadinessCheck(
        label: 'Speaker assignment',
        passed: speakersAssigned,
        points: speakersAssigned ? 20 : 0,
        maximum: 20,
      ),
    );

    final screenshotIndexes = active
        .map((message) => message.sourceScreenshotIndex)
        .whereType<int>()
        .toList();
    var sourceOrderIsValid = true;
    for (var index = 1; index < screenshotIndexes.length; index++) {
      if (screenshotIndexes[index] < screenshotIndexes[index - 1]) {
        sourceOrderIsValid = false;
      }
    }
    checks.add(
      ReadinessCheck(
        label: 'Screenshot order',
        passed: sourceOrderIsValid,
        points: sourceOrderIsValid ? 10 : 0,
        maximum: 10,
      ),
    );

    final normalizedTexts = active
        .map(
          (message) =>
              '${message.eventType.wireName}:${message.speaker.name}:'
              '${message.text.trim().toLowerCase()}',
        )
        .where((text) => text.isNotEmpty)
        .toList();
    final noDuplicates =
        normalizedTexts.toSet().length == normalizedTexts.length;
    checks.add(
      ReadinessCheck(
        label: 'Duplicate messages',
        passed: noDuplicates,
        points: noDuplicates ? 10 : 0,
        maximum: 10,
      ),
    );

    final timestampCoverage = active.isEmpty
        ? 0.0
        : active.where((message) => message.timestamp != null).length /
              active.length;
    final timestampPoints = (timestampCoverage * 5).round();
    checks.add(
      ReadinessCheck(
        label: 'Timestamp availability',
        passed: timestampCoverage >= 0.5,
        points: timestampPoints,
        maximum: 5,
      ),
    );

    final reviewedConfidence = activeEvents.map((message) {
      final confidence = math.min(
        message.ocrConfidence ?? 1,
        message.classificationConfidence ?? 1,
      );
      if (message.status == ReviewMessageStatus.edited ||
          message.status == ReviewMessageStatus.added) {
        return math.max(confidence, 0.9);
      }
      return confidence;
    }).toList();
    final averageConfidence = reviewedConfidence.isEmpty
        ? 0.0
        : reviewedConfidence.reduce((a, b) => a + b) /
              reviewedConfidence.length;
    final confidencePoints = (averageConfidence * 30).round().clamp(0, 30);
    checks.add(
      ReadinessCheck(
        label: 'OCR confidence',
        passed: activeEvents.every((message) => !message.needsReview),
        points: confidencePoints,
        maximum: 30,
      ),
    );

    final score = checks.fold<int>(0, (total, check) => total + check.points);
    return ReadinessReport(score: score.clamp(0, 100), checks: checks);
  }
}
