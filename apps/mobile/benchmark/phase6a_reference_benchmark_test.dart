import 'dart:io';

import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/real_conversation_ocr_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'phase6a/benchmark_harness.dart';
import 'phase6a/benchmark_session.dart';
import 'phase6a/fixture_catalog.dart';
import 'phase6a/reference_text_provider.dart';
import 'phase6a/report_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'runs provider-neutral Phase 6A reference benchmark',
    () async {
      await initializeDateFormatting();
      final fixtures = await BenchmarkFixtureCatalog.load();
      const harness = ExtractionBenchmarkHarness();
      final report = await harness.run(
        fixtures: fixtures,
        engineFactory: (fixture) => RealConversationOcrEngine(
          preprocessor: const SafeConversationImagePreprocessor(),
          textRecognitionProvider: FixtureReferenceTextRecognitionProvider(
            fixture.referencePages,
          ),
        ),
        sessionEnvironment: BenchmarkSessionEnvironment(
          platform: 'reference_host_${Platform.operatingSystem}',
          deviceModel: 'host_reference',
          osVersion: Platform.operatingSystemVersion,
          flutterVersion: const String.fromEnvironment(
            'PHASE6A_FLUTTER_VERSION',
            defaultValue: 'host_flutter_test',
          ),
          mlKitVersion: 'not_exercised_reference_provider',
          extractionVersion: 'conversation-extraction-v2-events',
        ),
        nativeDeviceRun: false,
      );
      const outputPath = String.fromEnvironment(
        'PHASE6A_OUTPUT_DIR',
        defaultValue: 'build/phase6a-benchmark/reference',
      );
      await const BenchmarkReportExporter().export(
        report.toJson(),
        Directory(outputPath),
      );

      expect(report.cases, hasLength(fixtures.length));
      expect(report.summary.failedCount, 0);
      expect(report.summary.cleanupSuccessRate, 1);
      expect(report.cancellationProbePassed, isTrue);
      expect(report.nativeDeviceRun, isFalse);
      expect(report.qualityGateStatus, 'BLOCKED');
      expect(
        report.qualityGates
            .where((gate) => gate.id != 'native_device_run')
            .every((gate) => !gate.required || gate.passed == true),
        isTrue,
        reason:
            'Every platform-independent gate must pass before physical qualification.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
