import 'dart:convert';
import 'dart:io';

import '../benchmark/phase6a/benchmark_comparison.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2 || arguments.length > 3) {
    stderr.writeln(
      'Usage: dart run tool/compare_phase6a_benchmarks.dart '
      '<previous-report.json> <current-report.json> [output-directory]',
    );
    exitCode = 64;
    return;
  }
  try {
    final previous = await _readReport(arguments[0]);
    final current = await _readReport(arguments[1]);
    final result = const BenchmarkReportComparator().compare(
      previous: previous,
      current: current,
    );
    final output = Directory(
      arguments.length == 3
          ? arguments[2]
          : 'build/phase6a-benchmark/comparison',
    );
    await const BenchmarkComparisonExporter().export(result, output);
    stdout.writeln(jsonEncode(result.toJson()));
    exitCode = result.hasBlockingRegression ? 2 : 0;
  } on FormatException catch (error) {
    stderr.writeln('Benchmark comparison rejected: ${error.message}');
    exitCode = 65;
  }
}

Future<Map<String, Object?>> _readReport(String path) async {
  final decoded = jsonDecode(await File(path).readAsString());
  if (decoded is! Map) throw const FormatException('Report must be an object.');
  return decoded.cast<String, Object?>();
}
