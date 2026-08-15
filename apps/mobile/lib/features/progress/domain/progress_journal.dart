import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:flutter/foundation.dart';

const progressJournalSchemaVersion = 'progress-journal.v1';

enum ReplyOutcome { received, notReceived, waiting }

enum PlanConfirmation { notDiscussed, needsConfirmation, confirmed, changed }

@immutable
class ConversationOutcome {
  const ConversationOutcome({
    required this.conversationId,
    required this.replyOutcome,
    required this.planConfirmation,
    required this.authenticityRating,
    required this.clarityRating,
    required this.boundaryRating,
    required this.updatedAt,
  }) : assert(authenticityRating >= 1 && authenticityRating <= 5),
       assert(clarityRating >= 1 && clarityRating <= 5),
       assert(boundaryRating >= 1 && boundaryRating <= 5);

  final String conversationId;
  final ReplyOutcome replyOutcome;
  final PlanConfirmation planConfirmation;
  final int authenticityRating;
  final int clarityRating;
  final int boundaryRating;
  final DateTime updatedAt;

  int get ratingTotal => authenticityRating + clarityRating + boundaryRating;
}

@immutable
class ProgressJournal {
  ProgressJournal({
    Iterable<ConversationOutcome> outcomes = const [],
    this.privateReflection = '',
  }) : outcomes = List.unmodifiable(outcomes) {
    if (privateReflection.length > 1000) {
      throw ArgumentError.value(
        privateReflection.length,
        'privateReflection',
        'Private reflections are limited to 1000 characters.',
      );
    }
    if (this.outcomes.map((item) => item.conversationId).toSet().length !=
        this.outcomes.length) {
      throw ArgumentError('Each conversation may have only one outcome.');
    }
  }

  final List<ConversationOutcome> outcomes;
  final String privateReflection;

  ProgressJournal copyWith({
    Iterable<ConversationOutcome>? outcomes,
    String? privateReflection,
  }) {
    return ProgressJournal(
      outcomes: outcomes ?? this.outcomes,
      privateReflection: privateReflection ?? this.privateReflection,
    );
  }
}

@immutable
class OverallProgressDashboard {
  const OverallProgressDashboard({
    required this.conversations,
    required this.journal,
    required this.communicationScore,
    required this.replyRate,
    required this.replySampleSize,
    required this.confirmedPlanCount,
    required this.awaitingClarityCount,
  });

  final List<ConversationSummary> conversations;
  final ProgressJournal journal;

  /// A self-reported average of authenticity, clarity, and boundary alignment.
  /// It never represents another person's interest or relationship quality.
  final int? communicationScore;
  final int? replyRate;
  final int replySampleSize;
  final int confirmedPlanCount;
  final int awaitingClarityCount;

  int get recordedConversationCount => journal.outcomes.length;
  bool get hasConversations => conversations.isNotEmpty;

  String get planSummary {
    if (recordedConversationCount == 0) return 'No plan status recorded';
    if (confirmedPlanCount > 0) {
      return confirmedPlanCount == 1
          ? '1 plan explicitly confirmed'
          : '$confirmedPlanCount plans explicitly confirmed';
    }
    if (awaitingClarityCount > 0) return 'Waiting for clear confirmation';
    return 'No plan is currently confirmed';
  }

  static OverallProgressDashboard calculate({
    required Iterable<ConversationSummary> conversations,
    required ProgressJournal journal,
  }) {
    final conversationList = List<ConversationSummary>.unmodifiable(
      conversations,
    );
    final activeIds = conversationList.map((item) => item.id).toSet();
    final activeOutcomes = journal.outcomes
        .where((item) => activeIds.contains(item.conversationId))
        .toList(growable: false);
    final activeJournal = journal.copyWith(outcomes: activeOutcomes);

    final totalRating = activeOutcomes.fold<int>(
      0,
      (sum, item) => sum + item.ratingTotal,
    );
    final communicationScore = activeOutcomes.isEmpty
        ? null
        : ((totalRating / (activeOutcomes.length * 15)) * 100).round();

    final decidedReplies = activeOutcomes
        .where((item) => item.replyOutcome != ReplyOutcome.waiting)
        .toList(growable: false);
    final repliesReceived = decidedReplies
        .where((item) => item.replyOutcome == ReplyOutcome.received)
        .length;
    final replyRate = decidedReplies.isEmpty
        ? null
        : ((repliesReceived / decidedReplies.length) * 100).round();
    final confirmedPlans = activeOutcomes
        .where((item) => item.planConfirmation == PlanConfirmation.confirmed)
        .length;
    final awaitingClarity = activeOutcomes
        .where(
          (item) => item.planConfirmation == PlanConfirmation.needsConfirmation,
        )
        .length;

    return OverallProgressDashboard(
      conversations: conversationList,
      journal: activeJournal,
      communicationScore: communicationScore,
      replyRate: replyRate,
      replySampleSize: decidedReplies.length,
      confirmedPlanCount: confirmedPlans,
      awaitingClarityCount: awaitingClarity,
    );
  }
}

extension ReplyOutcomeLabel on ReplyOutcome {
  String get label => switch (this) {
    ReplyOutcome.received => 'Reply received',
    ReplyOutcome.notReceived => 'No reply yet',
    ReplyOutcome.waiting => 'Still waiting',
  };
}

extension PlanConfirmationLabel on PlanConfirmation {
  String get label => switch (this) {
    PlanConfirmation.notDiscussed => 'Not discussed',
    PlanConfirmation.needsConfirmation => 'Needs clear confirmation',
    PlanConfirmation.confirmed => 'Explicitly confirmed',
    PlanConfirmation.changed => 'Changed or cancelled',
  };
}
