import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../benchmark/phase6a/benchmark_comparison.dart';
import '../benchmark/phase6a/benchmark_metrics.dart';
import '../benchmark/phase6a/benchmark_report.dart';
import '../benchmark/phase6a/benchmark_report_schema.dart';
import '../benchmark/phase6a/benchmark_session.dart';
import '../benchmark/phase6a/device_capability.dart';
import '../benchmark/phase6a/native_qualification_runner.dart';

void main() {
  group('benchmark v2 evidence', () {
    test('schema accepts content-free report and rejects added payloads', () {
      final report = _benchmarkReport(nativeDeviceRun: true).toJson();

      expect(() => BenchmarkReportSchema.validate(report), returnsNormally);
      expect(
        jsonDecode(
          File(
            'benchmark/phase6a/schema/benchmark-result-v2.schema.json',
          ).readAsStringSync(),
        ),
        isA<Map>(),
      );

      final unsafe = _copy(report)..['transcript'] = 'private content';
      expect(
        () => BenchmarkReportSchema.validate(unsafe),
        throwsA(isA<FormatException>()),
      );
      final stale = _copy(report)..['schema_version'] = 'phase6a-benchmark.v1';
      expect(
        () => BenchmarkReportSchema.validate(stale),
        throwsA(isA<FormatException>()),
      );
    });

    test('quality gate is explicit for native and non-native evidence', () {
      final native = _benchmarkReport(nativeDeviceRun: true);
      final host = _benchmarkReport(nativeDeviceRun: false);

      expect(native.qualityGateStatus, 'PASS');
      expect(host.qualityGateStatus, 'BLOCKED');
      expect(native.session.success, isTrue);
      expect(native.session.cancellationResult.name, 'passed');
    });

    test('session recorder captures cancellation and rejects double close', () {
      final recorder = BenchmarkSessionRecorder.start(
        _environment,
        clock: () => DateTime.utc(2026, 7, 15, 10),
      );
      final session = recorder.complete(
        failureCount: 0,
        cancelledCaseCount: 1,
        peakRssBytes: 120,
        peakRssDeltaBytes: 20,
        cancellationProbePassed: false,
      );

      expect(session.outcome, BenchmarkSessionOutcome.cancelled);
      expect(session.success, isFalse);
      expect(session.cancellationResult, BenchmarkCancellationResult.failed);
      expect(
        () => recorder.complete(
          failureCount: 0,
          cancelledCaseCount: 0,
          peakRssBytes: null,
          peakRssDeltaBytes: null,
          cancellationProbePassed: true,
        ),
        throwsStateError,
      );
    });

    test('comparison reports quality and performance regressions', () async {
      final previous = _benchmarkReport(nativeDeviceRun: true).toJson();
      final current = _copy(previous);
      final summary = (current['summary']! as Map).cast<String, Object?>();
      summary['word_accuracy'] = 0.97;
      summary['p95_latency_ms'] = 1300;
      final result = const BenchmarkReportComparator().compare(
        previous: previous,
        current: current,
      );

      expect(result.status, 'REGRESSION');
      expect(result.hasBlockingRegression, isTrue);
      expect(
        result.regressions.map((item) => item.id),
        containsAll({'word_accuracy', 'p95_latency_ms'}),
      );

      final output = await Directory.systemTemp.createTemp(
        'convocoach-phase6a2-comparison-',
      );
      try {
        await const BenchmarkComparisonExporter().export(result, output);
        final exported = await File(
          '${output.path}/comparison.json',
        ).readAsString();
        expect(exported, contains('word_accuracy'));
        expect(exported, isNot(contains('synthetic private message')));
      } finally {
        await output.delete(recursive: true);
      }
    });
  });

  group('native capability and runner', () {
    test(
      'detects tools and physical devices without exporting identifiers',
      () async {
        final runner = _FakeCommandRunner({
          'flutter --version --machine': QualificationCommandResult(
            exitCode: 0,
            stdout: jsonEncode({'frameworkVersion': '3.41.0'}),
            stderr: '',
          ),
          'adb version': const QualificationCommandResult(
            exitCode: 0,
            stdout: 'Android Debug Bridge version 1.0.41',
            stderr: '',
          ),
          'xcodebuild -version': const QualificationCommandResult(
            exitCode: 0,
            stdout: 'Xcode 26.0\nBuild version 1',
            stderr: '',
          ),
          'pod --version': const QualificationCommandResult(
            exitCode: 0,
            stdout: '1.16.2',
            stderr: '',
          ),
          'flutter devices --machine': QualificationCommandResult(
            exitCode: 0,
            stdout: jsonEncode([
              {
                'name': 'Private Android Name',
                'id': 'private-android-id',
                'targetPlatform': 'android-arm64',
                'emulator': false,
                'isSupported': true,
                'sdk': 'Android 16',
              },
              {
                'name': 'Private iPhone Name',
                'id': 'private-ios-id',
                'targetPlatform': 'ios',
                'emulator': false,
                'isSupported': true,
                'sdk': 'iOS 26',
              },
            ]),
            stderr: '',
          ),
        });
        final report = await NativeDeviceCapabilityDetector(
          commandRunner: runner,
          clock: () => DateTime.utc(2026, 7, 15),
        ).detect();

        expect(report.status, 'PASS');
        expect(report.androidReady, isTrue);
        expect(report.iosReady, isTrue);
        final evidence = jsonEncode(report.toJson());
        expect(evidence, isNot(contains('private-android-id')));
        expect(evidence, isNot(contains('Private Android Name')));
        expect(evidence, contains('android-arm64'));
      },
    );

    test('reports truthful blockers when native tooling is absent', () async {
      final runner = _FakeCommandRunner(const {});
      final report = await NativeDeviceCapabilityDetector(
        commandRunner: runner,
        clock: () => DateTime.utc(2026, 7, 15),
      ).detect();

      expect(report.status, 'BLOCKED');
      expect(
        report.androidBlockers,
        containsAll({
          'flutter_unavailable',
          'android_sdk_unavailable',
          'physical_android_device_unavailable',
        }),
      );
      expect(
        report.iosBlockers,
        containsAll({
          'xcode_unavailable',
          'cocoapods_unavailable',
          'physical_ios_device_unavailable',
        }),
      );
    });

    test('runner executes only a qualified physical target', () async {
      final runner = _FakeCommandRunner({
        'flutter drive --driver=test_driver/phase6a_benchmark_driver.dart '
                '--target=integration_test/phase6a_android_benchmark_test.dart '
                '-d private-device-id '
                '--dart-define=PHASE6A_FLUTTER_VERSION=3.41.0':
            const QualificationCommandResult(
              exitCode: 0,
              stdout: 'passed',
              stderr: '',
            ),
      });
      final result = await NativeQualificationRunner(commandRunner: runner).run(
        platform: 'android',
        capability: _readyCapability,
        mobileDirectory: '/workspace/apps/mobile',
        flutterVersion: '3.41.0',
      );

      expect(result.status, 'PASS');
      expect(result.exitCode, 0);
      expect(jsonEncode(result.toJson()), isNot(contains('private-device-id')));
      expect(runner.calls, hasLength(1));
    });

    test(
      'runner blocks unavailable and unsupported platforms without execution',
      () async {
        final runner = _FakeCommandRunner(const {});
        final blocked = await NativeQualificationRunner(commandRunner: runner)
            .run(
              platform: 'android',
              capability: _blockedCapability,
              mobileDirectory: '/workspace/apps/mobile',
            );
        final unsupported =
            await NativeQualificationRunner(commandRunner: runner).run(
              platform: 'web',
              capability: _blockedCapability,
              mobileDirectory: '/workspace/apps/mobile',
            );

        expect(blocked.status, 'BLOCKED');
        expect(blocked.failureCategory, contains('android_sdk_unavailable'));
        expect(unsupported.failureCategory, 'unsupported_platform');
        expect(runner.calls, isEmpty);
        expect(
          const NativeDeviceCapabilityDetector().platformFamily('linux-x64'),
          isNull,
        );
      },
    );
  });
}

BenchmarkSuiteReport _benchmarkReport({required bool nativeDeviceRun}) {
  final session = BenchmarkSessionRecord(
    environment: _environment,
    startedAt: DateTime.utc(2026, 7, 15, 10),
    completedAt: DateTime.utc(2026, 7, 15, 10, 0, 1),
    elapsedMilliseconds: 1000,
    peakRssBytes: 50 * 1024 * 1024,
    peakRssDeltaBytes: 5 * 1024 * 1024,
    outcome: BenchmarkSessionOutcome.completed,
    success: true,
    failureCount: 0,
    cancelledCaseCount: 0,
    cancellationResult: BenchmarkCancellationResult.passed,
  );
  return BenchmarkSuiteReport(
    generatedAt: session.completedAt,
    session: session,
    nativeDeviceRun: nativeDeviceRun,
    cancellationProbePassed: true,
    cases: const [
      BenchmarkCaseResult(
        fixtureId: 'synthetic-fixture',
        inspiration: 'original',
        traits: {'synthetic'},
        imageCount: 1,
        expectedMessageCount: 1,
        status: BenchmarkCaseStatus.completed,
        latencyMilliseconds: 1000,
        peakRssBytes: 50 * 1024 * 1024,
        peakRssDeltaBytes: 5 * 1024 * 1024,
        cleanupSucceeded: true,
        provider: 'synthetic',
        providerVersion: '1',
        confidenceAvailable: true,
        metrics: BenchmarkMetrics(
          characterAccuracy: 1,
          wordAccuracy: 1,
          messageExtractionAccuracy: 1,
          eventClassificationAccuracy: 1,
          speakerAssignmentAccuracy: 1,
          timestampAccuracy: 1,
          duplicateRemovalAccuracy: 1,
          orderingAccuracy: 1,
          warningAccuracy: 1,
          manualReviewRate: 0,
          reviewRecall: 1,
          reviewPrecision: 1,
          corrections: BenchmarkCorrectionCounts(
            text: 0,
            speaker: 0,
            timestamp: 0,
            missing: 0,
            extra: 0,
            order: 0,
          ),
        ),
      ),
    ],
  );
}

Map<String, Object?> _copy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value))! as Map).cast<String, Object?>();

const _environment = BenchmarkSessionEnvironment(
  platform: 'android',
  deviceModel: 'synthetic-model',
  osVersion: 'Android 16',
  flutterVersion: '3.41.0',
  mlKitVersion: 'text-recognition-v2/plugin-0.16.0',
  extractionVersion: 'conversation-extraction-v2-events',
);

final _readyCapability = DeviceCapabilityReport(
  generatedAt: DateTime.utc(2026, 7, 15),
  tools: const [
    QualificationToolCapability(
      id: 'flutter',
      available: true,
      version: '3.41.0',
    ),
  ],
  devices: const [
    QualificationDevice(
      commandId: 'private-device-id',
      platform: 'android',
      targetPlatform: 'android-arm64',
      emulator: false,
      supported: true,
      sdk: 'Android 16',
    ),
  ],
  androidReady: true,
  iosReady: false,
  androidBlockers: const [],
  iosBlockers: const ['physical_ios_device_unavailable'],
);

final _blockedCapability = DeviceCapabilityReport(
  generatedAt: DateTime.utc(2026, 7, 15),
  tools: const [],
  devices: const [],
  androidReady: false,
  iosReady: false,
  androidBlockers: const ['android_sdk_unavailable'],
  iosBlockers: const ['xcode_unavailable'],
);

class _FakeCommandRunner implements QualificationCommandRunner {
  _FakeCommandRunner(this.results);

  final Map<String, QualificationCommandResult> results;
  final List<String> calls = [];

  @override
  Future<QualificationCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final key = '$executable ${arguments.join(' ')}';
    calls.add(key);
    return results[key] ??
        const QualificationCommandResult(
          exitCode: 127,
          stdout: '',
          stderr: 'not installed',
        );
  }
}
