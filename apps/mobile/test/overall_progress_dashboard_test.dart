import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversations/data/conversation_summary_dto.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:convo_coach/features/progress/domain/progress_journal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  group('overall progress calculation', () {
    test(
      'aggregates only user-recorded outcomes from existing conversations',
      () {
        final dashboard = OverallProgressDashboard.calculate(
          conversations: _domainConversations,
          journal: ProgressJournal(
            outcomes: [
              _outcome(
                conversationId: 'conversation-1',
                reply: ReplyOutcome.received,
                plan: PlanConfirmation.confirmed,
                authenticity: 5,
                clarity: 4,
                boundary: 3,
              ),
              _outcome(
                conversationId: 'conversation-2',
                reply: ReplyOutcome.notReceived,
                plan: PlanConfirmation.needsConfirmation,
                authenticity: 3,
                clarity: 3,
                boundary: 3,
              ),
              _outcome(
                conversationId: 'deleted-conversation',
                reply: ReplyOutcome.received,
                plan: PlanConfirmation.confirmed,
                authenticity: 5,
                clarity: 5,
                boundary: 5,
              ),
            ],
          ),
        );

        expect(dashboard.recordedConversationCount, 2);
        expect(dashboard.communicationScore, 70);
        expect(dashboard.replyRate, 50);
        expect(dashboard.replySampleSize, 2);
        expect(dashboard.confirmedPlanCount, 1);
        expect(dashboard.awaitingClarityCount, 1);
        expect(dashboard.planSummary, '1 plan explicitly confirmed');
      },
    );

    test('never turns waiting outcomes into failed replies', () {
      final dashboard = OverallProgressDashboard.calculate(
        conversations: _domainConversations.take(1),
        journal: ProgressJournal(
          outcomes: [
            _outcome(
              conversationId: 'conversation-1',
              reply: ReplyOutcome.waiting,
              plan: PlanConfirmation.notDiscussed,
              authenticity: 3,
              clarity: 3,
              boundary: 3,
            ),
          ],
        ),
      );

      expect(dashboard.replyRate, isNull);
      expect(dashboard.replySampleSize, 0);
      expect(dashboard.communicationScore, 60);
    });
  });

  group('overall progress presentation', () {
    testWidgets('shows one transparent aggregate without per-chat scores', (
      tester,
    ) async {
      final repository = MemoryProgressJournalRepository(
        ProgressJournal(
          outcomes: [
            _outcome(
              conversationId: 'conversation-1',
              reply: ReplyOutcome.received,
              plan: PlanConfirmation.confirmed,
              authenticity: 5,
              clarity: 4,
              boundary: 3,
            ),
            _outcome(
              conversationId: 'conversation-2',
              reply: ReplyOutcome.notReceived,
              plan: PlanConfirmation.needsConfirmation,
              authenticity: 3,
              clarity: 3,
              boundary: 3,
            ),
          ],
        ),
      );
      await pumpConvoCoach(
        tester,
        initialLocation: '/progress',
        conversationApiClient: MockConversationApiClient(
          conversations: _conversationDtos,
        ),
        progressJournalRepository: repository,
      );

      expect(find.text('Overall stats'), findsOneWidget);
      expect(find.byKey(const Key('overall-score-hero')), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.textContaining('never an interest'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Reply performance'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Plan confirmation'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('1 plan explicitly confirmed'), findsOneWidget);
      expect(find.text('Sam'), findsNothing);
      expect(find.text('Alex'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('records an outcome only after a user action', (tester) async {
      final repository = MemoryProgressJournalRepository();
      await pumpConvoCoach(
        tester,
        initialLocation: '/progress',
        conversationApiClient: MockConversationApiClient(
          conversations: _conversationDtos.take(1).toList(),
        ),
        progressJournalRepository: repository,
      );

      expect(find.text('Add your first outcome'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('record-outcome-action')),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('record-outcome-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('outcome-sheet')), findsOneWidget);
      expect(
        find.textContaining('No conversation receives a score'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('save-outcome-action')),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const Key('save-outcome-action')));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('overall-stats-list')),
        const Offset(0, 2400),
      );
      await tester.pumpAndSettle();
      expect(find.text('60'), findsOneWidget);
      expect(find.text('Your overall stats are updated.'), findsOneWidget);
      expect((await repository.load()).outcomes, hasLength(1));
    });

    testWidgets(
      'keeps the dashboard usable with reduced motion and large text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 700);
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.binding.platformDispatcher
              .clearAccessibilityFeaturesTestValue();
        });

        await pumpConvoCoach(
          tester,
          initialLocation: '/progress',
          conversationApiClient: MockConversationApiClient(
            conversations: _conversationDtos,
          ),
          progressJournalRepository: MemoryProgressJournalRepository(),
        );

        expect(find.byKey(const Key('overall-stats-list')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('overall-score-animation')),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('overall-score-animation')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

ConversationOutcome _outcome({
  required String conversationId,
  required ReplyOutcome reply,
  required PlanConfirmation plan,
  required int authenticity,
  required int clarity,
  required int boundary,
}) {
  return ConversationOutcome(
    conversationId: conversationId,
    replyOutcome: reply,
    planConfirmation: plan,
    authenticityRating: authenticity,
    clarityRating: clarity,
    boundaryRating: boundary,
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}

final _domainConversations = [
  ConversationSummary(
    id: 'conversation-1',
    title: 'Weekend plans',
    participantName: 'Sam',
    messageCount: 10,
    updatedAt: DateTime.utc(2026, 8, 1),
  ),
  ConversationSummary(
    id: 'conversation-2',
    title: 'Coffee',
    participantName: 'Alex',
    messageCount: 8,
    updatedAt: DateTime.utc(2026, 8, 1),
  ),
];

final _conversationDtos = [
  for (final conversation in _domainConversations)
    ConversationSummaryDto(
      id: conversation.id,
      title: conversation.title,
      participantName: conversation.participantName,
      messageCount: conversation.messageCount,
      updatedAt: conversation.updatedAt,
    ),
];
