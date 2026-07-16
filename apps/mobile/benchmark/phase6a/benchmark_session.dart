const benchmarkResultSchemaVersion = 'phase6a-benchmark.v2';
const phase6aBenchmarkVersion = 'phase6a.2-v1';

enum BenchmarkSessionOutcome { completed, failed, cancelled }

enum BenchmarkCancellationResult { passed, failed }

class BenchmarkSessionEnvironment {
  const BenchmarkSessionEnvironment({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.flutterVersion,
    required this.mlKitVersion,
    required this.extractionVersion,
    this.benchmarkVersion = phase6aBenchmarkVersion,
  });

  final String platform;
  final String deviceModel;
  final String osVersion;
  final String flutterVersion;
  final String mlKitVersion;
  final String extractionVersion;
  final String benchmarkVersion;

  Map<String, Object> toJson() => {
    'platform': platform,
    'device_model': deviceModel,
    'os_version': osVersion,
    'flutter_version': flutterVersion,
    'ml_kit_version': mlKitVersion,
    'extraction_version': extractionVersion,
    'benchmark_version': benchmarkVersion,
  };
}

class BenchmarkSessionRecord {
  const BenchmarkSessionRecord({
    required this.environment,
    required this.startedAt,
    required this.completedAt,
    required this.elapsedMilliseconds,
    required this.peakRssBytes,
    required this.peakRssDeltaBytes,
    required this.outcome,
    required this.success,
    required this.failureCount,
    required this.cancelledCaseCount,
    required this.cancellationResult,
  });

  final BenchmarkSessionEnvironment environment;
  final DateTime startedAt;
  final DateTime completedAt;
  final int elapsedMilliseconds;
  final int? peakRssBytes;
  final int? peakRssDeltaBytes;
  final BenchmarkSessionOutcome outcome;
  final bool success;
  final int failureCount;
  final int cancelledCaseCount;
  final BenchmarkCancellationResult cancellationResult;

  Map<String, Object?> toJson() => {
    ...environment.toJson(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'completed_at': completedAt.toUtc().toIso8601String(),
    'elapsed_ms': elapsedMilliseconds,
    'peak_rss_bytes': peakRssBytes,
    'peak_rss_delta_bytes': peakRssDeltaBytes,
    'outcome': outcome.name,
    'success': success,
    'failure_count': failureCount,
    'cancelled_case_count': cancelledCaseCount,
    'cancellation_result': cancellationResult.name,
  };
}

class BenchmarkSessionRecorder {
  factory BenchmarkSessionRecorder.start(
    BenchmarkSessionEnvironment environment, {
    DateTime Function()? clock,
  }) {
    final resolvedClock = clock ?? DateTime.now;
    return BenchmarkSessionRecorder._(
      environment,
      resolvedClock,
      resolvedClock(),
      Stopwatch()..start(),
    );
  }

  BenchmarkSessionRecorder._(
    this.environment,
    this._clock,
    this._startedAt,
    this._stopwatch,
  );

  final BenchmarkSessionEnvironment environment;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  final Stopwatch _stopwatch;
  bool _completed = false;

  BenchmarkSessionRecord complete({
    required int failureCount,
    required int cancelledCaseCount,
    required int? peakRssBytes,
    required int? peakRssDeltaBytes,
    required bool cancellationProbePassed,
  }) {
    if (_completed) {
      throw StateError('A benchmark session can be completed only once.');
    }
    _completed = true;
    _stopwatch.stop();
    final success =
        failureCount == 0 && cancelledCaseCount == 0 && cancellationProbePassed;
    final outcome = failureCount > 0
        ? BenchmarkSessionOutcome.failed
        : cancelledCaseCount > 0
        ? BenchmarkSessionOutcome.cancelled
        : !cancellationProbePassed
        ? BenchmarkSessionOutcome.failed
        : BenchmarkSessionOutcome.completed;
    return BenchmarkSessionRecord(
      environment: environment,
      startedAt: _startedAt,
      completedAt: _clock(),
      elapsedMilliseconds: _stopwatch.elapsedMilliseconds,
      peakRssBytes: peakRssBytes,
      peakRssDeltaBytes: peakRssDeltaBytes,
      outcome: outcome,
      success: success,
      failureCount: failureCount,
      cancelledCaseCount: cancelledCaseCount,
      cancellationResult: cancellationProbePassed
          ? BenchmarkCancellationResult.passed
          : BenchmarkCancellationResult.failed,
    );
  }
}
