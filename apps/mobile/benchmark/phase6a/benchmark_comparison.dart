import 'dart:convert';
import 'dart:io';

import 'benchmark_report_schema.dart';

class BenchmarkRegression {
  const BenchmarkRegression({
    required this.id,
    required this.baseline,
    required this.current,
    required this.threshold,
    required this.blocking,
  });

  final String id;
  final num? baseline;
  final num? current;
  final String threshold;
  final bool blocking;

  Map<String, Object?> toJson() => {
    'id': id,
    'baseline': baseline,
    'current': current,
    'threshold': threshold,
    'blocking': blocking,
  };
}

class BenchmarkComparisonResult {
  const BenchmarkComparisonResult({
    required this.previousGeneratedAt,
    required this.currentGeneratedAt,
    required this.previousGateStatus,
    required this.currentGateStatus,
    required this.regressions,
  });

  final String previousGeneratedAt;
  final String currentGeneratedAt;
  final String previousGateStatus;
  final String currentGateStatus;
  final List<BenchmarkRegression> regressions;

  String get status => regressions.isEmpty ? 'NO_REGRESSION' : 'REGRESSION';
  bool get hasBlockingRegression => regressions.any((item) => item.blocking);

  Map<String, Object?> toJson() => {
    'schema_version': 'phase6a-benchmark-comparison.v1',
    'previous_generated_at': previousGeneratedAt,
    'current_generated_at': currentGeneratedAt,
    'previous_quality_gate_status': previousGateStatus,
    'current_quality_gate_status': currentGateStatus,
    'status': status,
    'has_blocking_regression': hasBlockingRegression,
    'regressions': regressions.map((item) => item.toJson()).toList(),
  };
}

class BenchmarkReportComparator {
  const BenchmarkReportComparator();

  BenchmarkComparisonResult compare({
    required Map<String, Object?> previous,
    required Map<String, Object?> current,
  }) {
    BenchmarkReportSchema.validate(previous);
    BenchmarkReportSchema.validate(current);
    final before = _map(previous['summary']);
    final after = _map(current['summary']);
    final regressions = <BenchmarkRegression>[];

    for (final key in _accuracyMetrics) {
      final baseline = _number(before[key]);
      final measured = _number(after[key]);
      if (measured < baseline - 0.005) {
        regressions.add(
          BenchmarkRegression(
            id: key,
            baseline: baseline,
            current: measured,
            threshold: 'drop > 0.005',
            blocking: true,
          ),
        );
      }
    }
    _addIncrease(
      regressions,
      id: 'manual_review_rate',
      baseline: _number(before['manual_review_rate']),
      current: _number(after['manual_review_rate']),
      absoluteAllowance: 0.02,
      blocking: true,
    );
    _addIncrease(
      regressions,
      id: 'failed_count',
      baseline: _number(before['failed_count']),
      current: _number(after['failed_count']),
      absoluteAllowance: 0,
      blocking: true,
    );
    _addIncrease(
      regressions,
      id: 'cancelled_count',
      baseline: _number(before['cancelled_count']),
      current: _number(after['cancelled_count']),
      absoluteAllowance: 0,
      blocking: true,
    );

    final oldLatency = _number(before['p95_latency_ms']);
    final newLatency = _number(after['p95_latency_ms']);
    if (newLatency > oldLatency * 1.15 && newLatency - oldLatency > 100) {
      regressions.add(
        BenchmarkRegression(
          id: 'p95_latency_ms',
          baseline: oldLatency,
          current: newLatency,
          threshold: 'increase > 15% and > 100 ms',
          blocking: false,
        ),
      );
    }
    final oldMemory = _nullableNumber(before['maximum_peak_rss_delta_bytes']);
    final newMemory = _nullableNumber(after['maximum_peak_rss_delta_bytes']);
    if (oldMemory != null &&
        newMemory != null &&
        newMemory > oldMemory * 1.20 &&
        newMemory - oldMemory > 10 * 1024 * 1024) {
      regressions.add(
        BenchmarkRegression(
          id: 'maximum_peak_rss_delta_bytes',
          baseline: oldMemory,
          current: newMemory,
          threshold: 'increase > 20% and > 10 MiB',
          blocking: false,
        ),
      );
    }
    final oldCleanup = _number(before['cleanup_success_rate']);
    final newCleanup = _number(after['cleanup_success_rate']);
    if (newCleanup < oldCleanup - 0.005) {
      regressions.add(
        BenchmarkRegression(
          id: 'cleanup_success_rate',
          baseline: oldCleanup,
          current: newCleanup,
          threshold: 'drop > 0.005',
          blocking: true,
        ),
      );
    }
    if (previous['quality_gate_status'] == 'PASS' &&
        current['quality_gate_status'] != 'PASS') {
      regressions.add(
        const BenchmarkRegression(
          id: 'quality_gate_status',
          baseline: 1,
          current: 0,
          threshold: 'must not move from PASS to BLOCKED',
          blocking: true,
        ),
      );
    }

    return BenchmarkComparisonResult(
      previousGeneratedAt: previous['generated_at']! as String,
      currentGeneratedAt: current['generated_at']! as String,
      previousGateStatus: previous['quality_gate_status']! as String,
      currentGateStatus: current['quality_gate_status']! as String,
      regressions: List.unmodifiable(regressions),
    );
  }

  static const _accuracyMetrics = {
    'character_accuracy',
    'word_accuracy',
    'message_extraction_accuracy',
    'event_classification_accuracy',
    'minimum_fixture_message_extraction_accuracy',
    'speaker_assignment_accuracy',
    'timestamp_accuracy',
    'duplicate_removal_accuracy',
    'ordering_accuracy',
    'warning_accuracy',
    'review_recall',
    'review_precision',
  };

  void _addIncrease(
    List<BenchmarkRegression> regressions, {
    required String id,
    required num baseline,
    required num current,
    required num absoluteAllowance,
    required bool blocking,
  }) {
    if (current > baseline + absoluteAllowance) {
      regressions.add(
        BenchmarkRegression(
          id: id,
          baseline: baseline,
          current: current,
          threshold: 'increase > $absoluteAllowance',
          blocking: blocking,
        ),
      );
    }
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw const FormatException('Benchmark summary must be an object.');
  }

  num _number(Object? value) {
    if (value is num) return value;
    throw const FormatException('Compared metric must be numeric.');
  }

  num? _nullableNumber(Object? value) {
    if (value == null) return null;
    return _number(value);
  }
}

class BenchmarkComparisonExporter {
  const BenchmarkComparisonExporter();

  Future<void> export(
    BenchmarkComparisonResult result,
    Directory outputDirectory,
  ) async {
    await outputDirectory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await File(
      '${outputDirectory.path}/comparison.json',
    ).writeAsString('${encoder.convert(result.toJson())}\n', flush: true);
    final buffer = StringBuffer()
      ..writeln('# Phase 6A Benchmark Comparison')
      ..writeln()
      ..writeln('- Status: ${result.status}')
      ..writeln('- Previous gate: ${result.previousGateStatus}')
      ..writeln('- Current gate: ${result.currentGateStatus}')
      ..writeln('- Blocking regression: ${result.hasBlockingRegression}')
      ..writeln()
      ..writeln('| Metric | Previous | Current | Threshold | Blocking |')
      ..writeln('| --- | ---: | ---: | --- | --- |');
    for (final item in result.regressions) {
      buffer.writeln(
        '| ${item.id} | ${item.baseline} | ${item.current} | '
        '${item.threshold} | ${item.blocking} |',
      );
    }
    if (result.regressions.isEmpty) {
      buffer.writeln('| none | - | - | - | false |');
    }
    buffer
      ..writeln()
      ..writeln(
        'This comparison contains aggregate metrics only; it contains no '
        'screenshots, transcripts, source paths, or source hashes.',
      );
    await File(
      '${outputDirectory.path}/comparison.md',
    ).writeAsString(buffer.toString(), flush: true);
  }
}
