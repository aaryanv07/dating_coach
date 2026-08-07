import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/progress/data/secure_progress_journal_repository.dart';
import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:convo_coach/features/progress/domain/progress_journal_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final progressJournalRepositoryProvider = Provider<ProgressJournalRepository>((
  ref,
) {
  return SecureProgressJournalRepository();
});

class ProgressDashboardController
    extends AsyncNotifier<OverallProgressDashboard> {
  @override
  Future<OverallProgressDashboard> build() async {
    final conversations = await ref.watch(conversationListProvider.future);
    final repository = ref.watch(progressJournalRepositoryProvider);
    final journal = await repository.load();
    final dashboard = OverallProgressDashboard.calculate(
      conversations: conversations,
      journal: journal,
    );
    if (dashboard.journal.outcomes.length != journal.outcomes.length) {
      await repository.save(dashboard.journal);
    }
    return dashboard;
  }

  Future<bool> recordOutcome(ConversationOutcome outcome) async {
    final current = state.value;
    if (current == null ||
        !current.conversations.any(
          (conversation) => conversation.id == outcome.conversationId,
        )) {
      return false;
    }
    final nextOutcomes = [
      for (final existing in current.journal.outcomes)
        if (existing.conversationId != outcome.conversationId) existing,
      outcome,
    ];
    final nextJournal = current.journal.copyWith(outcomes: nextOutcomes);
    return _persist(nextJournal, current.conversations);
  }

  Future<bool> savePrivateReflection(String value) async {
    final current = state.value;
    final normalized = value.trim();
    if (current == null || normalized.length > 1000) return false;
    return _persist(
      current.journal.copyWith(privateReflection: normalized),
      current.conversations,
    );
  }

  Future<bool> clearJournal() async {
    final current = state.value;
    if (current == null) return false;
    try {
      await ref.read(progressJournalRepositoryProvider).clear();
      state = AsyncData(
        OverallProgressDashboard.calculate(
          conversations: current.conversations,
          journal: ProgressJournal(),
        ),
      );
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> _persist(
    ProgressJournal journal,
    List<ConversationSummary> conversations,
  ) async {
    try {
      await ref.read(progressJournalRepositoryProvider).save(journal);
      state = AsyncData(
        OverallProgressDashboard.calculate(
          conversations: conversations,
          journal: journal,
        ),
      );
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final progressDashboardProvider =
    AsyncNotifierProvider<
      ProgressDashboardController,
      OverallProgressDashboard
    >(ProgressDashboardController.new);
