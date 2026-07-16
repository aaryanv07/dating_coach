import 'dart:math' as math;

import 'benchmark_metrics.dart';
import 'benchmark_session.dart';

enum BenchmarkCaseStatus { completed, failed, cancelled }

class BenchmarkCaseResult {
  const BenchmarkCaseResult({
    required this.fixtureId,
    required this.inspiration,
    required this.traits,
    required this.imageCount,
    required this.expectedMessageCount,
    required this.status,
    required this.latencyMilliseconds,
    required this.peakRssBytes,
    required this.peakRssDeltaBytes,
    required this.cleanupSucceeded,
    required this.provider,
    required this.providerVersion,
    required this.confidenceAvailable,
    this.metrics,
    this.failureCategory,
  });

  final String fixtureId;
  final String inspiration;
  final Set<String> traits;
  final int imageCount;
  final int expectedMessageCount;
  final BenchmarkCaseStatus status;
  final int latencyMilliseconds;
  final int? peakRssBytes;
  final int? peakRssDeltaBytes;
  final bool cleanupSucceeded;
  final String provider;
  final String providerVersion;
  final bool confidenceAvailable;
  final BenchmarkMetrics? metrics;
  final String? failureCategory;

  BenchmarkCaseResult copyWithCleanup(bool value) => BenchmarkCaseResult(
    fixtureId: fixtureId,
    inspiration: inspiration,
    traits: traits,
    imageCount: imageCount,
    expectedMessageCount: expectedMessageCount,
    status: status,
    latencyMilliseconds: latencyMilliseconds,
    peakRssBytes: peakRssBytes,
    peakRssDeltaBytes: peakRssDeltaBytes,
    cleanupSucceeded: value,
    provider: provider,
    providerVersion: providerVersion,
    confidenceAvailable: confidenceAvailable,
    metrics: metrics,
    failureCategory: failureCategory,
  );

  Map<String, Object?> toJson() => {
    'fixture_id': fixtureId,
    'inspiration': inspiration,
    'traits': traits.toList()..sort(),
    'image_count': imageCount,
    'expected_message_count': expectedMessageCount,
    'status': status.name,
    'latency_ms': latencyMilliseconds,
    'peak_rss_bytes': peakRssBytes,
    'peak_rss_delta_bytes': peakRssDeltaBytes,
    'cleanup_succeeded': cleanupSucceeded,
    'provider': provider,
    'provider_version': providerVersion,
    'confidence_available': confidenceAvailable,
    'metrics': metrics?.toJson(),
    'failure_category': failureCategory,
  };
}

class BenchmarkSummary {
  const BenchmarkSummary({
    required this.fixtureCount,
    required this.completedCount,
    required this.failedCount,
    required this.cancelledCount,
    required this.characterAccuracy,
    required this.wordAccuracy,
    required this.messageExtractionAccuracy,
    required this.eventClassificationAccuracy,
    required this.minimumFixtureMessageExtractionAccuracy,
    required this.speakerAssignmentAccuracy,
    required this.timestampAccuracy,
    required this.duplicateRemovalAccuracy,
    required this.orderingAccuracy,
    required this.warningAccuracy,
    required this.manualReviewRate,
    required this.reviewRecall,
    required this.reviewPrecision,
    required this.averageCorrectionCount,
    required this.p50LatencyMilliseconds,
    required this.p95LatencyMilliseconds,
    required this.maximumPeakRssDeltaBytes,
    required this.cleanupSuccessRate,
    required this.confidenceAvailableForAll,
  });

  factory BenchmarkSummary.fromCases(List<BenchmarkCaseResult> cases) {
    final completed = cases
        .where(
          (result) =>
              result.status == BenchmarkCaseStatus.completed &&
              result.metrics != null,
        )
        .toList(growable: false);
    double average(double Function(BenchmarkMetrics metrics) select) {
      if (completed.isEmpty) return 0;
      return completed
              .map((result) => select(result.metrics!))
              .reduce((first, second) => first + second) /
          completed.length;
    }

    double minimum(double Function(BenchmarkMetrics metrics) select) {
      if (completed.isEmpty) return 0;
      return completed
          .map((result) => select(result.metrics!))
          .reduce((first, second) => first < second ? first : second);
    }

    final latencies =
        completed.map((result) => result.latencyMilliseconds).toList()..sort();
    final memoryDeltas = completed
        .map((result) => result.peakRssDeltaBytes)
        .whereType<int>()
        .toList();
    return BenchmarkSummary(
      fixtureCount: cases.length,
      completedCount: completed.length,
      failedCount: cases
          .where((result) => result.status == BenchmarkCaseStatus.failed)
          .length,
      cancelledCount: cases
          .where((result) => result.status == BenchmarkCaseStatus.cancelled)
          .length,
      characterAccuracy: average((metrics) => metrics.characterAccuracy),
      wordAccuracy: average((metrics) => metrics.wordAccuracy),
      messageExtractionAccuracy: average(
        (metrics) => metrics.messageExtractionAccuracy,
      ),
      eventClassificationAccuracy: average(
        (metrics) => metrics.eventClassificationAccuracy,
      ),
      minimumFixtureMessageExtractionAccuracy: minimum(
        (metrics) => metrics.messageExtractionAccuracy,
      ),
      speakerAssignmentAccuracy: average(
        (metrics) => metrics.speakerAssignmentAccuracy,
      ),
      timestampAccuracy: average((metrics) => metrics.timestampAccuracy),
      duplicateRemovalAccuracy: average(
        (metrics) => metrics.duplicateRemovalAccuracy,
      ),
      orderingAccuracy: average((metrics) => metrics.orderingAccuracy),
      warningAccuracy: average((metrics) => metrics.warningAccuracy),
      manualReviewRate: average((metrics) => metrics.manualReviewRate),
      reviewRecall: average((metrics) => metrics.reviewRecall),
      reviewPrecision: average((metrics) => metrics.reviewPrecision),
      averageCorrectionCount: average(
        (metrics) => metrics.corrections.total.toDouble(),
      ),
      p50LatencyMilliseconds: _percentile(latencies, 0.5),
      p95LatencyMilliseconds: _percentile(latencies, 0.95),
      maximumPeakRssDeltaBytes: memoryDeltas.isEmpty
          ? null
          : memoryDeltas.reduce(math.max),
      cleanupSuccessRate: cases.isEmpty
          ? 1
          : cases.where((result) => result.cleanupSucceeded).length /
                cases.length,
      confidenceAvailableForAll: completed.every(
        (result) => result.confidenceAvailable,
      ),
    );
  }

  final int fixtureCount;
  final int completedCount;
  final int failedCount;
  final int cancelledCount;
  final double characterAccuracy;
  final double wordAccuracy;
  final double messageExtractionAccuracy;
  final double eventClassificationAccuracy;
  final double minimumFixtureMessageExtractionAccuracy;
  final double speakerAssignmentAccuracy;
  final double timestampAccuracy;
  final double duplicateRemovalAccuracy;
  final double orderingAccuracy;
  final double warningAccuracy;
  final double manualReviewRate;
  final double reviewRecall;
  final double reviewPrecision;
  final double averageCorrectionCount;
  final int p50LatencyMilliseconds;
  final int p95LatencyMilliseconds;
  final int? maximumPeakRssDeltaBytes;
  final double cleanupSuccessRate;
  final bool confidenceAvailableForAll;

  Map<String, Object?> toJson() => {
    'fixture_count': fixtureCount,
    'completed_count': completedCount,
    'failed_count': failedCount,
    'cancelled_count': cancelledCount,
    'character_accuracy': characterAccuracy,
    'word_accuracy': wordAccuracy,
    'message_extraction_accuracy': messageExtractionAccuracy,
    'event_classification_accuracy': eventClassificationAccuracy,
    'minimum_fixture_message_extraction_accuracy':
        minimumFixtureMessageExtractionAccuracy,
    'speaker_assignment_accuracy': speakerAssignmentAccuracy,
    'timestamp_accuracy': timestampAccuracy,
    'duplicate_removal_accuracy': duplicateRemovalAccuracy,
    'ordering_accuracy': orderingAccuracy,
    'warning_accuracy': warningAccuracy,
    'manual_review_rate': manualReviewRate,
    'review_recall': reviewRecall,
    'review_precision': reviewPrecision,
    'average_correction_count': averageCorrectionCount,
    'p50_latency_ms': p50LatencyMilliseconds,
    'p95_latency_ms': p95LatencyMilliseconds,
    'maximum_peak_rss_delta_bytes': maximumPeakRssDeltaBytes,
    'cleanup_success_rate': cleanupSuccessRate,
    'confidence_available_for_all': confidenceAvailableForAll,
  };
}

class BenchmarkQualityGateResult {
  const BenchmarkQualityGateResult({
    required this.id,
    required this.description,
    required this.actual,
    required this.target,
    required this.required,
    required this.passed,
  });

  final String id;
  final String description;
  final double? actual;
  final double? target;
  final bool required;
  final bool? passed;

  Map<String, Object?> toJson() => {
    'id': id,
    'description': description,
    'actual': actual,
    'target': target,
    'required': required,
    'passed': passed,
  };
}

class BenchmarkQualityPolicy {
  const BenchmarkQualityPolicy._();

  static List<BenchmarkQualityGateResult> evaluate(
    BenchmarkSummary summary, {
    required bool nativeDeviceRun,
    required bool cancellationProbePassed,
  }) {
    final memoryMeasured = summary.maximumPeakRssDeltaBytes != null;
    final confidenceGateRequired = summary.confidenceAvailableForAll;
    return [
      _minimum('character_accuracy', summary.characterAccuracy, 0.95),
      _minimum('word_accuracy', summary.wordAccuracy, 0.90),
      _minimum(
        'message_extraction_accuracy',
        summary.messageExtractionAccuracy,
        0.95,
      ),
      _minimum(
        'event_classification_accuracy',
        summary.eventClassificationAccuracy,
        0.95,
      ),
      _minimum(
        'minimum_fixture_message_extraction_accuracy',
        summary.minimumFixtureMessageExtractionAccuracy,
        0.90,
      ),
      _minimum(
        'speaker_assignment_accuracy',
        summary.speakerAssignmentAccuracy,
        0.95,
      ),
      _minimum('timestamp_accuracy', summary.timestampAccuracy, 0.98),
      _minimum(
        'duplicate_removal_accuracy',
        summary.duplicateRemovalAccuracy,
        0.95,
      ),
      _minimum('ordering_accuracy', summary.orderingAccuracy, 1),
      _minimum('warning_accuracy', summary.warningAccuracy, 0.90),
      _minimum('review_recall', summary.reviewRecall, 0.95),
      _maximum(
        'manual_review_rate',
        summary.manualReviewRate,
        0.30,
        required: confidenceGateRequired,
      ),
      _maximum(
        'p95_latency_ms',
        summary.p95LatencyMilliseconds.toDouble(),
        2500,
      ),
      _maximum(
        'peak_rss_delta_bytes',
        summary.maximumPeakRssDeltaBytes?.toDouble(),
        200 * 1024 * 1024,
        required: memoryMeasured,
      ),
      _minimum('cleanup_success_rate', summary.cleanupSuccessRate, 1),
      BenchmarkQualityGateResult(
        id: 'cancellation_probe',
        description: 'Cancellation discards work and cleans temporary files.',
        actual: cancellationProbePassed ? 1 : 0,
        target: 1,
        required: true,
        passed: cancellationProbePassed,
      ),
      BenchmarkQualityGateResult(
        id: 'no_failed_cases',
        description: 'The fixture suite completes without extraction failures.',
        actual: summary.failedCount.toDouble(),
        target: 0,
        required: true,
        passed: summary.failedCount == 0,
      ),
      BenchmarkQualityGateResult(
        id: 'no_cancelled_cases',
        description: 'The fixture suite completes without cancelled cases.',
        actual: summary.cancelledCount.toDouble(),
        target: 0,
        required: true,
        passed: summary.cancelledCount == 0,
      ),
      BenchmarkQualityGateResult(
        id: 'native_device_run',
        description: 'Results were measured on a native Android or iOS device.',
        actual: nativeDeviceRun ? 1 : 0,
        target: 1,
        required: true,
        passed: nativeDeviceRun,
      ),
    ];
  }

  static BenchmarkQualityGateResult _minimum(
    String id,
    double? actual,
    double target, {
    bool required = true,
  }) {
    return BenchmarkQualityGateResult(
      id: id,
      description: '$id must be at least $target.',
      actual: actual,
      target: target,
      required: required,
      passed: actual == null ? null : actual >= target,
    );
  }

  static BenchmarkQualityGateResult _maximum(
    String id,
    double? actual,
    double target, {
    bool required = true,
  }) {
    return BenchmarkQualityGateResult(
      id: id,
      description: '$id must be no more than $target.',
      actual: actual,
      target: target,
      required: required,
      passed: actual == null ? null : actual <= target,
    );
  }
}

class BenchmarkSuiteReport {
  BenchmarkSuiteReport({
    required this.generatedAt,
    required this.session,
    required this.nativeDeviceRun,
    required this.cancellationProbePassed,
    required this.cases,
  }) : summary = BenchmarkSummary.fromCases(cases),
       qualityGates = BenchmarkQualityPolicy.evaluate(
         BenchmarkSummary.fromCases(cases),
         nativeDeviceRun: nativeDeviceRun,
         cancellationProbePassed: cancellationProbePassed,
       );

  final DateTime generatedAt;
  final BenchmarkSessionRecord session;
  final bool nativeDeviceRun;
  final bool cancellationProbePassed;
  final List<BenchmarkCaseResult> cases;
  final BenchmarkSummary summary;
  final List<BenchmarkQualityGateResult> qualityGates;

  bool get requiredQualityGatesPass => qualityGates
      .where((gate) => gate.required)
      .every((gate) => gate.passed == true);

  String get qualityGateStatus => requiredQualityGatesPass ? 'PASS' : 'BLOCKED';

  Map<String, Object?> toJson() => {
    'schema_version': benchmarkResultSchemaVersion,
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'runtime_platform': session.environment.platform,
    'runtime_version': session.environment.osVersion,
    'native_device_run': nativeDeviceRun,
    'cancellation_probe_passed': cancellationProbePassed,
    'required_quality_gates_pass': requiredQualityGatesPass,
    'quality_gate_status': qualityGateStatus,
    'session': session.toJson(),
    'summary': summary.toJson(),
    'quality_gates': qualityGates.map((gate) => gate.toJson()).toList(),
    'cases': cases.map((result) => result.toJson()).toList(),
  };
}

int _percentile(List<int> sortedValues, double percentile) {
  if (sortedValues.isEmpty) return 0;
  final index = ((sortedValues.length - 1) * percentile).ceil();
  return sortedValues[index.clamp(0, sortedValues.length - 1)];
}
