import 'package:convo_coach/features/progress/domain/progress_journal.dart';

abstract interface class ProgressJournalRepository {
  Future<ProgressJournal> load();

  Future<void> save(ProgressJournal journal);

  Future<void> clear();
}

class MemoryProgressJournalRepository implements ProgressJournalRepository {
  MemoryProgressJournalRepository([ProgressJournal? initial])
    : _journal = initial ?? ProgressJournal();

  ProgressJournal _journal;

  @override
  Future<ProgressJournal> load() async => _journal;

  @override
  Future<void> save(ProgressJournal journal) async {
    _journal = journal;
  }

  @override
  Future<void> clear() async {
    _journal = ProgressJournal();
  }
}
