import 'benchmark_session.dart';

/// Strict, dependency-free validation for the content-free benchmark payload.
///
/// The checked shape mirrors `schema/benchmark-result-v2.schema.json`. Keeping
/// this validator beside the writer lets command-line comparison tooling reject
/// stale, malformed, or privacy-unsafe reports before using them.
class BenchmarkReportSchema {
  const BenchmarkReportSchema._();

  static void validate(Map<String, Object?> report) {
    _exactKeys(report, _rootKeys, 'report');
    _string(report, 'schema_version', expected: benchmarkResultSchemaVersion);
    _string(report, 'generated_at');
    _string(report, 'runtime_platform');
    _string(report, 'runtime_version');
    _boolean(report, 'native_device_run');
    _boolean(report, 'cancellation_probe_passed');
    _boolean(report, 'required_quality_gates_pass');
    _enumString(report, 'quality_gate_status', const {'PASS', 'BLOCKED'});

    final session = _map(report, 'session');
    _exactKeys(session, _sessionKeys, 'session');
    for (final key in const {
      'platform',
      'device_model',
      'os_version',
      'flutter_version',
      'ml_kit_version',
      'extraction_version',
      'benchmark_version',
      'started_at',
      'completed_at',
      'outcome',
      'cancellation_result',
    }) {
      _string(session, key);
    }
    for (final key in const {
      'elapsed_ms',
      'failure_count',
      'cancelled_case_count',
    }) {
      _integer(session, key, minimum: 0);
    }
    _nullableInteger(session, 'peak_rss_bytes', minimum: 0);
    _nullableInteger(session, 'peak_rss_delta_bytes', minimum: 0);
    _boolean(session, 'success');
    _enumString(session, 'outcome', const {'completed', 'failed', 'cancelled'});
    _enumString(session, 'cancellation_result', const {'passed', 'failed'});

    final summary = _map(report, 'summary');
    _exactKeys(summary, _summaryKeys, 'summary');
    for (final key in const {
      'fixture_count',
      'completed_count',
      'failed_count',
      'cancelled_count',
      'p50_latency_ms',
      'p95_latency_ms',
    }) {
      _integer(summary, key, minimum: 0);
    }
    for (final key in _ratioSummaryKeys) {
      _number(summary, key, minimum: 0, maximum: 1);
    }
    _number(summary, 'average_correction_count', minimum: 0);
    _nullableInteger(summary, 'maximum_peak_rss_delta_bytes', minimum: 0);
    _boolean(summary, 'confidence_available_for_all');

    for (final value in _list(report, 'quality_gates')) {
      final gate = _object(value, 'quality_gates item');
      _exactKeys(gate, _gateKeys, 'quality gate');
      _string(gate, 'id');
      _string(gate, 'description');
      _nullableNumber(gate, 'actual');
      _nullableNumber(gate, 'target');
      _boolean(gate, 'required');
      _nullableBoolean(gate, 'passed');
    }

    for (final value in _list(report, 'cases')) {
      final item = _object(value, 'cases item');
      _exactKeys(item, _caseKeys, 'benchmark case');
      for (final key in const {
        'fixture_id',
        'inspiration',
        'status',
        'provider',
        'provider_version',
      }) {
        _string(item, key);
      }
      _enumString(item, 'status', const {'completed', 'failed', 'cancelled'});
      for (final key in const {
        'image_count',
        'expected_message_count',
        'latency_ms',
      }) {
        _integer(item, key, minimum: 0);
      }
      _nullableInteger(item, 'peak_rss_bytes', minimum: 0);
      _nullableInteger(item, 'peak_rss_delta_bytes', minimum: 0);
      _boolean(item, 'cleanup_succeeded');
      _boolean(item, 'confidence_available');
      _nullableString(item, 'failure_category');
      final traits = _list(item, 'traits');
      if (traits.any((trait) => trait is! String || trait.isEmpty)) {
        throw const FormatException('traits must contain non-empty strings.');
      }
      if (item['metrics'] case final metricsValue?) {
        final metrics = _object(metricsValue, 'metrics');
        _exactKeys(metrics, _metricKeys, 'metrics');
        for (final key in _metricRatioKeys) {
          _number(metrics, key, minimum: 0, maximum: 1);
        }
        final corrections = _map(metrics, 'corrections');
        _exactKeys(corrections, _correctionKeys, 'corrections');
        for (final key in _correctionKeys) {
          _integer(corrections, key, minimum: 0);
        }
      }
    }
  }

  static const _rootKeys = {
    'schema_version',
    'generated_at',
    'runtime_platform',
    'runtime_version',
    'native_device_run',
    'cancellation_probe_passed',
    'required_quality_gates_pass',
    'quality_gate_status',
    'session',
    'summary',
    'quality_gates',
    'cases',
  };
  static const _sessionKeys = {
    'platform',
    'device_model',
    'os_version',
    'flutter_version',
    'ml_kit_version',
    'extraction_version',
    'benchmark_version',
    'started_at',
    'completed_at',
    'elapsed_ms',
    'peak_rss_bytes',
    'peak_rss_delta_bytes',
    'outcome',
    'success',
    'failure_count',
    'cancelled_case_count',
    'cancellation_result',
  };
  static const _summaryKeys = {
    'fixture_count',
    'completed_count',
    'failed_count',
    'cancelled_count',
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
    'manual_review_rate',
    'review_recall',
    'review_precision',
    'average_correction_count',
    'p50_latency_ms',
    'p95_latency_ms',
    'maximum_peak_rss_delta_bytes',
    'cleanup_success_rate',
    'confidence_available_for_all',
  };
  static const _ratioSummaryKeys = {
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
    'manual_review_rate',
    'review_recall',
    'review_precision',
    'cleanup_success_rate',
  };
  static const _gateKeys = {
    'id',
    'description',
    'actual',
    'target',
    'required',
    'passed',
  };
  static const _caseKeys = {
    'fixture_id',
    'inspiration',
    'traits',
    'image_count',
    'expected_message_count',
    'status',
    'latency_ms',
    'peak_rss_bytes',
    'peak_rss_delta_bytes',
    'cleanup_succeeded',
    'provider',
    'provider_version',
    'confidence_available',
    'metrics',
    'failure_category',
  };
  static const _metricKeys = {
    'character_accuracy',
    'word_accuracy',
    'message_extraction_accuracy',
    'event_classification_accuracy',
    'speaker_assignment_accuracy',
    'timestamp_accuracy',
    'duplicate_removal_accuracy',
    'ordering_accuracy',
    'warning_accuracy',
    'manual_review_rate',
    'review_recall',
    'review_precision',
    'corrections',
  };
  static const _metricRatioKeys = {
    'character_accuracy',
    'word_accuracy',
    'message_extraction_accuracy',
    'event_classification_accuracy',
    'speaker_assignment_accuracy',
    'timestamp_accuracy',
    'duplicate_removal_accuracy',
    'ordering_accuracy',
    'warning_accuracy',
    'manual_review_rate',
    'review_recall',
    'review_precision',
  };
  static const _correctionKeys = {
    'text',
    'speaker',
    'timestamp',
    'missing',
    'extra',
    'order',
    'total',
  };

  static void _exactKeys(
    Map<String, Object?> value,
    Set<String> expected,
    String label,
  ) {
    final actual = value.keys.toSet();
    if (!actual.containsAll(expected) || !expected.containsAll(actual)) {
      throw FormatException('$label has unsupported or missing fields.');
    }
  }

  static Map<String, Object?> _map(Map<String, Object?> map, String key) =>
      _object(map[key], key);

  static Map<String, Object?> _object(Object? value, String label) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw FormatException('$label must be an object.');
  }

  static List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    throw FormatException('$key must be a list.');
  }

  static String _string(
    Map<String, Object?> map,
    String key, {
    String? expected,
  }) {
    final value = map[key];
    if (value is! String ||
        value.isEmpty ||
        (expected != null && value != expected)) {
      throw FormatException('$key must be a valid non-empty string.');
    }
    return value;
  }

  static void _nullableString(Map<String, Object?> map, String key) {
    if (map[key] != null) _string(map, key);
  }

  static void _enumString(
    Map<String, Object?> map,
    String key,
    Set<String> allowed,
  ) {
    if (!allowed.contains(_string(map, key))) {
      throw FormatException('$key has an unsupported value.');
    }
  }

  static void _integer(Map<String, Object?> map, String key, {int? minimum}) {
    final value = map[key];
    if (value is! int || (minimum != null && value < minimum)) {
      throw FormatException('$key must be a valid integer.');
    }
  }

  static void _nullableInteger(
    Map<String, Object?> map,
    String key, {
    int? minimum,
  }) {
    if (map[key] != null) _integer(map, key, minimum: minimum);
  }

  static void _number(
    Map<String, Object?> map,
    String key, {
    num? minimum,
    num? maximum,
  }) {
    final value = map[key];
    if (value is! num ||
        (minimum != null && value < minimum) ||
        (maximum != null && value > maximum)) {
      throw FormatException('$key must be a valid number.');
    }
  }

  static void _nullableNumber(Map<String, Object?> map, String key) {
    if (map[key] != null) _number(map, key);
  }

  static void _boolean(Map<String, Object?> map, String key) {
    if (map[key] is! bool) throw FormatException('$key must be a boolean.');
  }

  static void _nullableBoolean(Map<String, Object?> map, String key) {
    if (map[key] != null) _boolean(map, key);
  }
}
