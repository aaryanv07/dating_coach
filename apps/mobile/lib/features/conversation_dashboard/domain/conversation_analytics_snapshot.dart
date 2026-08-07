import 'package:flutter/foundation.dart';

const conversationAnalyticsSchemaVersion = 'conversation-analytics.v1';
const conversationAnalyticsCalculationVersion =
    'deterministic-conversation-analytics.v1';
const conversationEventSchemaVersion = 'conversation-events.v1';

enum AnalyticsMetricUnit {
  count,
  percent,
  seconds,
  eventId,
  reactionTypeCounts,
}

enum AnalyticsConfidence { complete, reduced, unavailable }

enum AnalyticsMissingDataReason {
  incompleteReview,
  missingTimestamp,
  estimatedTimestamp,
  missingParticipant,
  unknownEvent,
  unresolvedRelationship,
  incompleteTimeline,
  partialConversation,
  insufficientEvidence,
}

@immutable
class AnalyticsEvidenceReferenceV1 {
  AnalyticsEvidenceReferenceV1({
    Iterable<String> eventIds = const [],
    Iterable<String> relationshipIds = const [],
    this.calculationVersion = conversationAnalyticsCalculationVersion,
  }) : eventIds = List.unmodifiable(eventIds),
       relationshipIds = List.unmodifiable(relationshipIds);

  final List<String> eventIds;
  final List<String> relationshipIds;
  final String calculationVersion;

  bool get isAvailable => eventIds.isNotEmpty || relationshipIds.isNotEmpty;
}

@immutable
class AnalyticsQualityV1 {
  AnalyticsQualityV1({
    required this.supported,
    required this.confidence,
    Iterable<AnalyticsMissingDataReason> missingData = const [],
    this.reviewStatus = 'confirmed',
    this.incompleteTimeline = false,
  }) : missingData = List.unmodifiable(missingData) {
    if (supported && confidence == AnalyticsConfidence.unavailable) {
      throw ArgumentError('Supported analytics cannot be unavailable.');
    }
    if (!supported && confidence != AnalyticsConfidence.unavailable) {
      throw ArgumentError('Unsupported analytics must be unavailable.');
    }
  }

  final bool supported;
  final AnalyticsConfidence confidence;
  final List<AnalyticsMissingDataReason> missingData;
  final String reviewStatus;
  final bool incompleteTimeline;

  bool get unsupported => !supported;
}

sealed class AnalyticsMetricValueV1 {
  const AnalyticsMetricValueV1();
}

@immutable
class AnalyticsNumberValueV1 extends AnalyticsMetricValueV1 {
  const AnalyticsNumberValueV1(this.value);

  final num value;
}

@immutable
class AnalyticsIdentifierValueV1 extends AnalyticsMetricValueV1 {
  const AnalyticsIdentifierValueV1(this.value);

  final String value;
}

@immutable
class AnalyticsReactionTypeCountV1 {
  const AnalyticsReactionTypeCountV1({
    required this.reactionType,
    required this.count,
    required this.evidence,
  });

  final String reactionType;
  final int count;
  final AnalyticsEvidenceReferenceV1 evidence;
}

@immutable
class AnalyticsReactionCountsValueV1 extends AnalyticsMetricValueV1 {
  AnalyticsReactionCountsValueV1(Iterable<AnalyticsReactionTypeCountV1> values)
    : values = List.unmodifiable(values);

  final List<AnalyticsReactionTypeCountV1> values;
}

@immutable
class AnalyticsMetricV1 {
  const AnalyticsMetricV1({
    required this.identifier,
    required this.description,
    required this.value,
    required this.unit,
    required this.evidence,
    required this.quality,
  });

  final String identifier;
  final String description;
  final AnalyticsMetricValueV1? value;
  final AnalyticsMetricUnit unit;
  final AnalyticsEvidenceReferenceV1 evidence;
  final AnalyticsQualityV1 quality;
}

/// Read-only mobile projection of an immutable Phase 6B analytics result.
///
/// It deliberately contains no conversation text, screenshots, OCR output,
/// persistence metadata, or formulas. The deterministic engine remains the
/// only component that calculates metric values.
@immutable
class ConversationAnalyticsSnapshotV1 {
  ConversationAnalyticsSnapshotV1({
    required Iterable<AnalyticsMetricV1> metrics,
    required this.quality,
    this.sourceSchemaVersion = conversationEventSchemaVersion,
    this.calculationVersion = conversationAnalyticsCalculationVersion,
    this.schemaVersion = conversationAnalyticsSchemaVersion,
  }) : metrics = List.unmodifiable(metrics);

  final List<AnalyticsMetricV1> metrics;
  final AnalyticsQualityV1 quality;
  final String sourceSchemaVersion;
  final String calculationVersion;
  final String schemaVersion;
}
