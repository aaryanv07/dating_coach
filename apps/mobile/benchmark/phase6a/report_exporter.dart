import 'dart:convert';
import 'dart:io';

import 'benchmark_report_schema.dart';

class BenchmarkExportPaths {
  const BenchmarkExportPaths({required this.json, required this.markdown});

  final File json;
  final File markdown;
}

class BenchmarkReportExporter {
  const BenchmarkReportExporter();

  Future<BenchmarkExportPaths> export(
    Map<String, Object?> report,
    Directory outputDirectory,
  ) async {
    BenchmarkReportSchema.validate(report);
    await outputDirectory.create(recursive: true);
    final jsonFile = File('${outputDirectory.path}/report.json');
    final markdownFile = File('${outputDirectory.path}/report.md');
    const encoder = JsonEncoder.withIndent('  ');
    await jsonFile.writeAsString('${encoder.convert(report)}\n', flush: true);
    await markdownFile.writeAsString(_markdown(report), flush: true);
    return BenchmarkExportPaths(json: jsonFile, markdown: markdownFile);
  }

  String _markdown(Map<String, Object?> report) {
    final summary = _map(report['summary']);
    final session = _map(report['session']);
    final gates = _list(report['quality_gates']);
    final cases = _list(report['cases']);
    final buffer = StringBuffer()
      ..writeln('# Phase 6A Extraction Benchmark')
      ..writeln()
      ..writeln('- Generated: ${report['generated_at']}')
      ..writeln('- Runtime: ${report['runtime_platform']}')
      ..writeln('- Native device: ${report['native_device_run']}')
      ..writeln('- Quality gate status: ${report['quality_gate_status']}')
      ..writeln('- Device model: ${session['device_model']}')
      ..writeln('- OS version: ${session['os_version']}')
      ..writeln('- Flutter version: ${session['flutter_version']}')
      ..writeln('- ML Kit version: ${session['ml_kit_version']}')
      ..writeln('- Extraction version: ${session['extraction_version']}')
      ..writeln('- Benchmark version: ${session['benchmark_version']}')
      ..writeln('- Session elapsed ms: ${session['elapsed_ms']}')
      ..writeln('- Session outcome: ${session['outcome']}')
      ..writeln(
        '- Required gates pass: ${report['required_quality_gates_pass']}',
      )
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln('| Metric | Result |')
      ..writeln('| --- | ---: |');
    for (final entry in summary.entries) {
      buffer.writeln('| ${_label(entry.key)} | ${_value(entry.value)} |');
    }
    buffer
      ..writeln()
      ..writeln('## Quality Gates')
      ..writeln()
      ..writeln('| Gate | Actual | Target | Required | Passed |')
      ..writeln('| --- | ---: | ---: | --- | --- |');
    for (final item in gates) {
      final gate = _map(item);
      buffer.writeln(
        '| ${gate['id']} | ${_value(gate['actual'])} | '
        '${_value(gate['target'])} | ${gate['required']} | ${gate['passed']} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Fixture Results')
      ..writeln()
      ..writeln('| Fixture | Status | Latency ms | Corrections | Cleanup |')
      ..writeln('| --- | --- | ---: | ---: | --- |');
    for (final item in cases) {
      final result = _map(item);
      final metrics = result['metrics'] == null
          ? <String, Object?>{}
          : _map(result['metrics']);
      final corrections = metrics['corrections'] == null
          ? <String, Object?>{}
          : _map(metrics['corrections']);
      buffer.writeln(
        '| ${result['fixture_id']} | ${result['status']} | '
        '${result['latency_ms']} | ${corrections['total'] ?? '-'} | '
        '${result['cleanup_succeeded']} |',
      );
    }
    buffer.writeln();
    buffer.writeln(
      'This report contains aggregate metrics and synthetic fixture IDs only. '
      'It does not contain screenshots, extracted transcripts, or source hashes.',
    );
    return buffer.toString();
  }

  String _label(String value) => value.replaceAll('_', ' ');

  String _value(Object? value) {
    if (value == null) return 'not measured';
    if (value is double) return value.toStringAsFixed(4);
    return value.toString();
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw FormatException('Benchmark report section must be an object.');
  }

  List<Object?> _list(Object? value) {
    if (value is List<Object?>) return value;
    if (value is List) return value.cast<Object?>();
    throw FormatException('Benchmark report section must be a list.');
  }
}
