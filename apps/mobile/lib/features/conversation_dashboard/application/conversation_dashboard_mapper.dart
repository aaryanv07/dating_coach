import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_snapshot.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/dashboard_view_model.dart';

class ConversationDashboardMapper {
  const ConversationDashboardMapper();

  ConversationDashboardState map(ConversationAnalyticsSnapshotV1? analytics) {
    if (analytics == null) return const ConversationDashboardEmpty();

    if (analytics.schemaVersion != conversationAnalyticsSchemaVersion ||
        analytics.calculationVersion !=
            conversationAnalyticsCalculationVersion ||
        analytics.sourceSchemaVersion != conversationEventSchemaVersion) {
      return const ConversationDashboardUnsupported(
        'This analytics version is not supported by this app yet.',
      );
    }

    final metricsByIdentifier = <String, AnalyticsMetricV1>{};
    for (final metric in analytics.metrics) {
      if (metricsByIdentifier.containsKey(metric.identifier)) {
        return const ConversationDashboardUnsupported(
          'This analytics result contains duplicate metric identifiers.',
        );
      }
      if ((metric.quality.supported && metric.value == null) ||
          (metric.quality.unsupported && metric.value != null)) {
        return const ConversationDashboardUnsupported(
          'This analytics result has an invalid availability state.',
        );
      }
      if (metric.value != null &&
          !_valueMatchesUnit(metric.value!, metric.unit)) {
        return const ConversationDashboardUnsupported(
          'This analytics result contains an unsupported metric value.',
        );
      }
      metricsByIdentifier[metric.identifier] = metric;
    }

    for (final section in _sectionSpecs) {
      for (final spec in section.metrics) {
        final metric = metricsByIdentifier[spec.identifier];
        if (metric == null || metric.unit != spec.unit) {
          return const ConversationDashboardUnsupported(
            'This analytics result is missing fields required by the dashboard.',
          );
        }
      }
    }

    final sections = [
      for (final section in _sectionSpecs)
        DashboardSectionViewModel(
          title: section.title,
          description: section.description,
          metrics: [
            for (final spec in section.metrics)
              _mapMetric(metricsByIdentifier[spec.identifier]!, spec),
          ],
        ),
    ];

    final allMissingReasons = <AnalyticsMissingDataReason>{
      ...analytics.quality.missingData,
      for (final metric in analytics.metrics) ...metric.quality.missingData,
    };
    final timelineGapMetric =
        metricsByIdentifier['structure.timeline_gaps']!.value;
    final timelineGapCount = switch (timelineGapMetric) {
      AnalyticsNumberValueV1(:final value) => value,
      _ => 0,
    };

    return ConversationDashboardReady(
      ConversationDashboardViewModel(
        sections: sections,
        quality: DashboardQualityViewModel(
          supportedMetricCount: analytics.metrics
              .where((metric) => metric.quality.supported)
              .length,
          unsupportedMetricCount: analytics.metrics
              .where((metric) => metric.quality.unsupported)
              .length,
          confidenceLabel: _confidenceLabel(analytics.quality.confidence),
          missingDataLabels: [
            for (final reason in AnalyticsMissingDataReason.values)
              if (allMissingReasons.contains(reason))
                _missingReasonLabel(reason),
          ],
          incompleteTimeline: analytics.quality.incompleteTimeline,
        ),
        hasTimelineGaps: timelineGapCount > 0,
        schemaVersion: analytics.schemaVersion,
        calculationVersion: analytics.calculationVersion,
      ),
    );
  }

  bool _valueMatchesUnit(
    AnalyticsMetricValueV1 value,
    AnalyticsMetricUnit unit,
  ) {
    return switch ((value, unit)) {
      (AnalyticsNumberValueV1(), AnalyticsMetricUnit.count) => true,
      (AnalyticsNumberValueV1(), AnalyticsMetricUnit.percent) => true,
      (AnalyticsNumberValueV1(), AnalyticsMetricUnit.seconds) => true,
      (AnalyticsIdentifierValueV1(), AnalyticsMetricUnit.eventId) => true,
      (
        AnalyticsReactionCountsValueV1(),
        AnalyticsMetricUnit.reactionTypeCounts,
      ) =>
        true,
      _ => false,
    };
  }

  DashboardMetricViewModel _mapMetric(
    AnalyticsMetricV1 metric,
    _MetricSpec spec,
  ) {
    return DashboardMetricViewModel(
      identifier: metric.identifier,
      label: spec.label,
      valueLabel: metric.quality.supported
          ? _formatValue(metric.value!, metric.unit)
          : 'Not available',
      supported: metric.quality.supported,
      confidenceLabel: _confidenceLabel(metric.quality.confidence),
      missingDataLabels: [
        for (final reason in metric.quality.missingData)
          _missingReasonLabel(reason),
      ],
      description: metric.description,
      evidence: metric.evidence,
    );
  }

  String _formatValue(AnalyticsMetricValueV1 value, AnalyticsMetricUnit unit) {
    return switch ((value, unit)) {
      (AnalyticsNumberValueV1(:final value), AnalyticsMetricUnit.count) =>
        value.toString(),
      (AnalyticsNumberValueV1(:final value), AnalyticsMetricUnit.percent) =>
        '${value.toStringAsFixed(1)}%',
      (AnalyticsNumberValueV1(:final value), AnalyticsMetricUnit.seconds) =>
        _formatDuration(value),
      (AnalyticsIdentifierValueV1(), AnalyticsMetricUnit.eventId) =>
        'Available in developer evidence',
      (
        AnalyticsReactionCountsValueV1(:final values),
        AnalyticsMetricUnit.reactionTypeCounts,
      ) =>
        values.isEmpty
            ? 'None observed'
            : values
                  .map((entry) => '${entry.reactionType}: ${entry.count}')
                  .join(', '),
      _ => 'Unsupported value',
    };
  }

  String _formatDuration(num secondsValue) {
    final seconds = secondsValue.round();
    if (seconds < 60) return '$seconds sec';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
    }
    return remainingSeconds == 0
        ? '$minutes min'
        : '$minutes min $remainingSeconds sec';
  }
}

String _confidenceLabel(AnalyticsConfidence confidence) {
  return switch (confidence) {
    AnalyticsConfidence.complete => 'Complete',
    AnalyticsConfidence.reduced => 'Reduced',
    AnalyticsConfidence.unavailable => 'Unavailable',
  };
}

String _missingReasonLabel(AnalyticsMissingDataReason reason) {
  return switch (reason) {
    AnalyticsMissingDataReason.incompleteReview => 'Review is incomplete',
    AnalyticsMissingDataReason.missingTimestamp => 'Timestamp is missing',
    AnalyticsMissingDataReason.estimatedTimestamp => 'Timestamp is estimated',
    AnalyticsMissingDataReason.missingParticipant =>
      'Participant attribution is missing',
    AnalyticsMissingDataReason.unknownEvent => 'Unknown event is present',
    AnalyticsMissingDataReason.unresolvedRelationship =>
      'Event relationship is unresolved',
    AnalyticsMissingDataReason.incompleteTimeline => 'Timeline is incomplete',
    AnalyticsMissingDataReason.partialConversation =>
      'Conversation import is partial',
    AnalyticsMissingDataReason.insufficientEvidence =>
      'There is not enough structural evidence',
  };
}

class _DashboardSectionSpec {
  const _DashboardSectionSpec({
    required this.title,
    required this.description,
    required this.metrics,
  });

  final String title;
  final String description;
  final List<_MetricSpec> metrics;
}

class _MetricSpec {
  const _MetricSpec(this.identifier, this.label, this.unit);

  final String identifier;
  final String label;
  final AnalyticsMetricUnit unit;
}

const _sectionSpecs = <_DashboardSectionSpec>[
  _DashboardSectionSpec(
    title: 'Conversation summary',
    description: 'Mechanical totals from the confirmed conversation timeline.',
    metrics: [
      _MetricSpec(
        'messages.total',
        'Messages and contributions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'conversation.total_user_events',
        'Your contributions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'conversation.total_other_events',
        'Other participant contributions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'conversation.duration_seconds',
        'Conversation duration',
        AnalyticsMetricUnit.seconds,
      ),
      _MetricSpec(
        'conversation.active_duration_seconds',
        'Active duration',
        AnalyticsMetricUnit.seconds,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Participation',
    description:
        'Counts only; these do not measure interest or relationship quality.',
    metrics: [
      _MetricSpec(
        'participation.conversation_starts',
        'Observed timeline sessions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.user.communication_events',
        'Your event count',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.user.participation_share_percent',
        'Your event share',
        AnalyticsMetricUnit.percent,
      ),
      _MetricSpec(
        'participant.user.initiations',
        'Sessions you initiated',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.user.consecutive_runs',
        'Your consecutive runs',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.other.communication_events',
        'Other participant event count',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.other.participation_share_percent',
        'Other participant event share',
        AnalyticsMetricUnit.percent,
      ),
      _MetricSpec(
        'participant.other.initiations',
        'Sessions the other participant initiated',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'participant.other.consecutive_runs',
        'Other participant consecutive runs',
        AnalyticsMetricUnit.count,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Timing',
    description:
        'Observed timestamp intervals, with unavailable results kept visible.',
    metrics: [
      _MetricSpec(
        'timing.response_latency_mean_seconds',
        'Mean response interval',
        AnalyticsMetricUnit.seconds,
      ),
      _MetricSpec(
        'timing.response_latency_median_seconds',
        'Median response interval',
        AnalyticsMetricUnit.seconds,
      ),
      _MetricSpec(
        'timing.response_latency_minimum_seconds',
        'Minimum response interval',
        AnalyticsMetricUnit.seconds,
      ),
      _MetricSpec(
        'timing.response_latency_maximum_seconds',
        'Maximum response interval',
        AnalyticsMetricUnit.seconds,
      ),
      _MetricSpec(
        'timing.unanswered_question_duration_seconds',
        'Observed unanswered-question duration',
        AnalyticsMetricUnit.seconds,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Questions',
    description: 'Literal question marks and explicit reply links only.',
    metrics: [
      _MetricSpec('questions.total', 'Questions', AnalyticsMetricUnit.count),
      _MetricSpec(
        'questions.answered',
        'Explicitly answered questions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'questions.unanswered',
        'Questions without an explicit reply',
        AnalyticsMetricUnit.count,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Replies',
    description:
        'Explicit structural reply references from the reviewed timeline.',
    metrics: [
      _MetricSpec(
        'replies.explicit',
        'Explicit replies',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'replies.orphan',
        'Reply references without a valid target',
        AnalyticsMetricUnit.count,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Reactions',
    description: 'Reaction events and their confirmed structural targets.',
    metrics: [
      _MetricSpec(
        'reactions.sent_by_user',
        'Reactions sent by you',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'reactions.sent_by_other',
        'Reactions sent by the other participant',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'reactions.received_by_user',
        'Reactions on your contributions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'reactions.received_by_other',
        'Reactions on other participant contributions',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'reactions.by_type',
        'Reaction types',
        AnalyticsMetricUnit.reactionTypeCounts,
      ),
      _MetricSpec(
        'reactions.targets',
        'Distinct reaction targets',
        AnalyticsMetricUnit.count,
      ),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Media',
    description:
        'Event-type counts without opening or inspecting attachment content.',
    metrics: [
      _MetricSpec('media.images', 'Images', AnalyticsMetricUnit.count),
      _MetricSpec('media.videos', 'Videos', AnalyticsMetricUnit.count),
      _MetricSpec(
        'media.voice_notes',
        'Voice notes',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec('media.documents', 'Documents', AnalyticsMetricUnit.count),
      _MetricSpec('media.links', 'Links', AnalyticsMetricUnit.count),
      _MetricSpec('media.locations', 'Locations', AnalyticsMetricUnit.count),
    ],
  ),
  _DashboardSectionSpec(
    title: 'Timeline structure',
    description:
        'Quality and structure markers retained by the canonical event model.',
    metrics: [
      _MetricSpec(
        'structure.timeline_gaps',
        'Timeline gaps',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'structure.duplicates',
        'Duplicate events excluded',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'structure.unknown_events',
        'Unknown events',
        AnalyticsMetricUnit.count,
      ),
      _MetricSpec(
        'structure.structural_events',
        'Structural events',
        AnalyticsMetricUnit.count,
      ),
    ],
  ),
];
