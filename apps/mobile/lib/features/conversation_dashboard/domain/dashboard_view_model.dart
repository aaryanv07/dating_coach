import 'package:convo_coach/features/conversation_dashboard/domain/conversation_analytics_snapshot.dart';
import 'package:flutter/foundation.dart';

@immutable
class DashboardMetricViewModel {
  DashboardMetricViewModel({
    required this.identifier,
    required this.label,
    required this.valueLabel,
    required this.supported,
    required this.confidenceLabel,
    required Iterable<String> missingDataLabels,
    required this.description,
    required this.evidence,
  }) : missingDataLabels = List.unmodifiable(missingDataLabels);

  final String identifier;
  final String label;
  final String valueLabel;
  final bool supported;
  final String confidenceLabel;
  final List<String> missingDataLabels;
  final String description;
  final AnalyticsEvidenceReferenceV1 evidence;
}

@immutable
class DashboardSectionViewModel {
  DashboardSectionViewModel({
    required this.title,
    required this.description,
    required Iterable<DashboardMetricViewModel> metrics,
  }) : metrics = List.unmodifiable(metrics);

  final String title;
  final String description;
  final List<DashboardMetricViewModel> metrics;
}

@immutable
class DashboardQualityViewModel {
  DashboardQualityViewModel({
    required this.supportedMetricCount,
    required this.unsupportedMetricCount,
    required this.confidenceLabel,
    required Iterable<String> missingDataLabels,
    required this.incompleteTimeline,
  }) : missingDataLabels = List.unmodifiable(missingDataLabels);

  final int supportedMetricCount;
  final int unsupportedMetricCount;
  final String confidenceLabel;
  final List<String> missingDataLabels;
  final bool incompleteTimeline;
}

@immutable
class ConversationDashboardViewModel {
  ConversationDashboardViewModel({
    required Iterable<DashboardSectionViewModel> sections,
    required this.quality,
    required this.hasTimelineGaps,
    required this.schemaVersion,
    required this.calculationVersion,
  }) : sections = List.unmodifiable(sections);

  final List<DashboardSectionViewModel> sections;
  final DashboardQualityViewModel quality;
  final bool hasTimelineGaps;
  final String schemaVersion;
  final String calculationVersion;
}

sealed class ConversationDashboardState {
  const ConversationDashboardState();
}

class ConversationDashboardEmpty extends ConversationDashboardState {
  const ConversationDashboardEmpty();
}

class ConversationDashboardUnsupported extends ConversationDashboardState {
  const ConversationDashboardUnsupported(this.message);

  final String message;
}

class ConversationDashboardReady extends ConversationDashboardState {
  const ConversationDashboardReady(this.dashboard);

  final ConversationDashboardViewModel dashboard;
}
