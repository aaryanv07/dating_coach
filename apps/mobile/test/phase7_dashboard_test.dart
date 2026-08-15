import 'dart:async';

import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/features/conversation_dashboard/application/conversation_dashboard_controller.dart';
import 'package:convo_coach/features/conversation_dashboard/application/conversation_dashboard_mapper.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_repository.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_snapshot.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  group('Phase 7 dashboard mapping', () {
    test('maps immutable Phase 6B values without recalculating metrics', () {
      final snapshot = _buildSnapshot();
      final result = const ConversationDashboardMapper().map(snapshot);

      expect(result, isA<ConversationDashboardReady>());
      final dashboard = (result as ConversationDashboardReady).dashboard;
      expect(dashboard.sections, hasLength(8));
      expect(dashboard.quality.supportedMetricCount, 39);
      expect(dashboard.quality.unsupportedMetricCount, 1);
      expect(dashboard.hasTimelineGaps, isTrue);
      expect(dashboard.sections.first.metrics.first.valueLabel, '3');
      expect(
        () => snapshot.metrics.add(snapshot.metrics.first),
        throwsUnsupportedError,
      );
      expect(
        () => dashboard.sections.add(dashboard.sections.first),
        throwsUnsupportedError,
      );
    });

    test('rejects unknown versions and incomplete dashboard contracts', () {
      final unsupportedVersion = _buildSnapshot(
        schemaVersion: 'conversation-analytics.v2',
      );
      final incomplete = ConversationAnalyticsSnapshotV1(
        metrics: [_buildSnapshot().metrics.first],
        quality: _supportedQuality,
      );

      expect(
        const ConversationDashboardMapper().map(unsupportedVersion),
        isA<ConversationDashboardUnsupported>(),
      );
      expect(
        const ConversationDashboardMapper().map(incomplete),
        isA<ConversationDashboardUnsupported>(),
      );
    });
  });

  group('Phase 7 dashboard presentation', () {
    testWidgets('shows an honest empty state when no analytics exist', (
      tester,
    ) async {
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/conversation-1/dashboard',
      );

      expect(find.text('No analytics available'), findsOneWidget);
      expect(
        find.textContaining('Confirm a reviewed conversation'),
        findsOneWidget,
      );
    });

    testWidgets('keeps unsupported metrics and timeline gaps visible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/conversation-1/dashboard',
        conversationAnalyticsRepository: _FixedAnalyticsRepository(
          _buildSnapshot(),
        ),
      );

      expect(find.text('Observed conversation data'), findsOneWidget);
      expect(find.text('Timeline gaps are present'), findsOneWidget);
      expect(find.text('39 supported'), findsOneWidget);
      expect(find.text('1 unavailable'), findsOneWidget);
      final unavailableMetric = find.byKey(
        const Key('dashboard-metric-timing.response_latency_median_seconds'),
      );
      await tester.scrollUntilVisible(
        unavailableMetric,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(unavailableMetric, findsOneWidget);
      expect(
        tester.getSemantics(unavailableMetric).label,
        contains(
          'Median response interval: Not available. Timeline is incomplete',
        ),
      );
      expect(find.text('Not available'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('developer evidence reveals only structural identifiers', (
      tester,
    ) async {
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/conversation-1/dashboard',
        conversationAnalyticsRepository: _FixedAnalyticsRepository(
          _buildSnapshot(),
        ),
      );

      await tester.fling(
        find.byKey(const Key('conversation-dashboard-list')),
        const Offset(0, -10000),
        10000,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('developer-evidence-tile')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Schema: conversation-analytics.v1'),
        findsOneWidget,
      );
      expect(find.textContaining('event-1'), findsWidgets);
      expect(find.textContaining('private message'), findsNothing);
      expect(find.textContaining('screenshot'), findsNothing);
    });

    testWidgets('renders a dedicated unsupported-data state', (tester) async {
      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/conversation-1/dashboard',
        conversationAnalyticsRepository: _FixedAnalyticsRepository(
          _buildSnapshot(schemaVersion: 'conversation-analytics.v2'),
        ),
      );

      expect(find.text('Unsupported analytics data'), findsOneWidget);
      expect(find.textContaining('not supported by this app'), findsOneWidget);
    });

    testWidgets('shows a loading state while analytics are requested', (
      tester,
    ) async {
      final router = createAppRouter(
        initialLocation: '/conversations/conversation-1/dashboard',
      );
      addTearDown(router.dispose);
      final completer = Completer<ConversationAnalyticsSnapshotV1?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationAnalyticsRepositoryProvider.overrideWithValue(
              _PendingAnalyticsRepository(completer.future),
            ),
          ],
          child: ConvoCoachApp(router: router),
        ),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Observed conversation data'), findsNothing);
      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('remains usable with large text on a compact phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pumpConvoCoach(
        tester,
        initialLocation: '/conversations/conversation-1/dashboard',
        conversationAnalyticsRepository: _FixedAnalyticsRepository(
          _buildSnapshot(),
        ),
      );

      expect(find.text('Observed conversation data'), findsOneWidget);
      final list = find.byKey(const Key('conversation-dashboard-list'));
      final scrollable = find.descendant(
        of: list,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      for (var index = 0; index < 10; index++) {
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
      }
      final evidenceTile = find.byKey(const Key('developer-evidence-tile'));
      expect(evidenceTile, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

final _supportedQuality = AnalyticsQualityV1(
  supported: true,
  confidence: AnalyticsConfidence.complete,
);

final _unsupportedTimingQuality = AnalyticsQualityV1(
  supported: false,
  confidence: AnalyticsConfidence.unavailable,
  missingData: const [AnalyticsMissingDataReason.incompleteTimeline],
  incompleteTimeline: true,
);

ConversationAnalyticsSnapshotV1 _buildSnapshot({
  String schemaVersion = conversationAnalyticsSchemaVersion,
}) {
  final evidence = AnalyticsEvidenceReferenceV1(
    eventIds: const ['event-1'],
    relationshipIds: const ['relationship-1'],
  );
  final metrics = <AnalyticsMetricV1>[];

  for (final identifier in _countMetricIdentifiers) {
    metrics.add(
      AnalyticsMetricV1(
        identifier: identifier,
        description: 'Deterministic structural count.',
        value: AnalyticsNumberValueV1(
          identifier == 'structure.timeline_gaps' ? 1 : 3,
        ),
        unit: AnalyticsMetricUnit.count,
        evidence: evidence,
        quality: _supportedQuality,
      ),
    );
  }
  for (final identifier in _percentMetricIdentifiers) {
    metrics.add(
      AnalyticsMetricV1(
        identifier: identifier,
        description: 'Deterministic event share.',
        value: const AnalyticsNumberValueV1(50),
        unit: AnalyticsMetricUnit.percent,
        evidence: evidence,
        quality: _supportedQuality,
      ),
    );
  }
  for (final identifier in _secondsMetricIdentifiers) {
    final unavailable = identifier == 'timing.response_latency_median_seconds';
    metrics.add(
      AnalyticsMetricV1(
        identifier: identifier,
        description: 'Deterministic timestamp interval.',
        value: unavailable ? null : const AnalyticsNumberValueV1(120),
        unit: AnalyticsMetricUnit.seconds,
        evidence: unavailable ? AnalyticsEvidenceReferenceV1() : evidence,
        quality: unavailable ? _unsupportedTimingQuality : _supportedQuality,
      ),
    );
  }
  metrics.add(
    AnalyticsMetricV1(
      identifier: 'reactions.by_type',
      description: 'Reviewed reaction metadata counts.',
      value: AnalyticsReactionCountsValueV1([
        AnalyticsReactionTypeCountV1(
          reactionType: 'like',
          count: 2,
          evidence: evidence,
        ),
      ]),
      unit: AnalyticsMetricUnit.reactionTypeCounts,
      evidence: evidence,
      quality: _supportedQuality,
    ),
  );

  return ConversationAnalyticsSnapshotV1(
    metrics: metrics,
    quality: AnalyticsQualityV1(
      supported: true,
      confidence: AnalyticsConfidence.reduced,
      missingData: const [AnalyticsMissingDataReason.incompleteTimeline],
      incompleteTimeline: true,
    ),
    schemaVersion: schemaVersion,
  );
}

const _countMetricIdentifiers = <String>[
  'messages.total',
  'conversation.total_user_events',
  'conversation.total_other_events',
  'participation.conversation_starts',
  'participant.user.communication_events',
  'participant.user.initiations',
  'participant.user.consecutive_runs',
  'participant.other.communication_events',
  'participant.other.initiations',
  'participant.other.consecutive_runs',
  'questions.total',
  'questions.answered',
  'questions.unanswered',
  'replies.explicit',
  'replies.orphan',
  'reactions.sent_by_user',
  'reactions.sent_by_other',
  'reactions.received_by_user',
  'reactions.received_by_other',
  'reactions.targets',
  'media.images',
  'media.videos',
  'media.voice_notes',
  'media.documents',
  'media.links',
  'media.locations',
  'structure.timeline_gaps',
  'structure.duplicates',
  'structure.unknown_events',
  'structure.structural_events',
];

const _percentMetricIdentifiers = <String>[
  'participant.user.participation_share_percent',
  'participant.other.participation_share_percent',
];

const _secondsMetricIdentifiers = <String>[
  'conversation.duration_seconds',
  'conversation.active_duration_seconds',
  'timing.response_latency_mean_seconds',
  'timing.response_latency_median_seconds',
  'timing.response_latency_minimum_seconds',
  'timing.response_latency_maximum_seconds',
  'timing.unanswered_question_duration_seconds',
];

class _FixedAnalyticsRepository implements ConversationAnalyticsRepository {
  const _FixedAnalyticsRepository(this.snapshot);

  final ConversationAnalyticsSnapshotV1 snapshot;

  @override
  Future<ConversationAnalyticsSnapshotV1?> getForConversation(
    String conversationId,
  ) async => snapshot;
}

class _PendingAnalyticsRepository implements ConversationAnalyticsRepository {
  const _PendingAnalyticsRepository(this.result);

  final Future<ConversationAnalyticsSnapshotV1?> result;

  @override
  Future<ConversationAnalyticsSnapshotV1?> getForConversation(
    String conversationId,
  ) => result;
}
