import 'package:convo_coach/features/progress/data/secure_progress_journal_repository.dart';
import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'protected journal round-trips only explicit outcome metadata',
    () async {
      final repository = SecureProgressJournalRepository();
      final journal = ProgressJournal(
        outcomes: [
          ConversationOutcome(
            conversationId: 'opaque-conversation-id',
            replyOutcome: ReplyOutcome.received,
            planConfirmation: PlanConfirmation.confirmed,
            authenticityRating: 5,
            clarityRating: 4,
            boundaryRating: 5,
            updatedAt: DateTime.utc(2026, 8, 1, 10),
          ),
        ],
        privateReflection: 'I chose a message that sounded like me.',
      );

      await repository.save(journal);
      final restored = await repository.load();

      expect(restored.outcomes, hasLength(1));
      expect(restored.outcomes.single.conversationId, 'opaque-conversation-id');
      expect(restored.outcomes.single.replyOutcome, ReplyOutcome.received);
      expect(
        restored.outcomes.single.planConfirmation,
        PlanConfirmation.confirmed,
      );
      expect(
        restored.privateReflection,
        'I chose a message that sounded like me.',
      );

      await repository.clear();
      expect((await repository.load()).outcomes, isEmpty);
      expect((await repository.load()).privateReflection, isEmpty);
    },
  );

  test('unsupported or malformed protected data fails closed', () async {
    FlutterSecureStorage.setMockInitialValues({
      'convocoach.progress-journal.v1':
          '{"schema_version":"progress-journal.v2","outcomes":[]}',
    });

    await expectLater(
      SecureProgressJournalRepository().load(),
      throwsA(isA<FormatException>()),
    );
  });
}
