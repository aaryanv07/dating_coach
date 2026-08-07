import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import '../benchmark/phase6a/report_exporter.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final report = data?['phase6a'];
      if (report is! Map) {
        throw StateError('The native benchmark did not return a report.');
      }
      final platform =
          Platform.environment['PHASE6A_PLATFORM_LABEL'] ?? 'native-device';
      await const BenchmarkReportExporter().export(
        report.cast<String, Object?>(),
        Directory('build/phase6a-benchmark/$platform'),
      );
    },
  );
}
