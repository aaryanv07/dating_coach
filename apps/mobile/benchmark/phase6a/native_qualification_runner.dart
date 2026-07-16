import 'dart:convert';
import 'dart:io';

import 'device_capability.dart';

class NativeQualificationRunResult {
  const NativeQualificationRunResult({
    required this.platform,
    required this.status,
    required this.exitCode,
    required this.failureCategory,
    required this.outputDirectory,
  });

  final String platform;
  final String status;
  final int? exitCode;
  final String? failureCategory;
  final String outputDirectory;

  Map<String, Object?> toJson() => {
    'schema_version': 'phase6a-native-run.v1',
    'platform': platform,
    'status': status,
    'exit_code': exitCode,
    'failure_category': failureCategory,
    'output_directory': outputDirectory,
  };
}

class NativeQualificationRunner {
  const NativeQualificationRunner({
    this.commandRunner = const ProcessQualificationCommandRunner(),
  });

  final QualificationCommandRunner commandRunner;

  Future<NativeQualificationRunResult> run({
    required String platform,
    required DeviceCapabilityReport capability,
    required String mobileDirectory,
    String? requestedDeviceId,
    String flutterVersion = 'unreported',
  }) async {
    if (platform != 'android' && platform != 'ios') {
      return NativeQualificationRunResult(
        platform: platform,
        status: 'BLOCKED',
        exitCode: null,
        failureCategory: 'unsupported_platform',
        outputDirectory: 'build/phase6a-benchmark/$platform',
      );
    }
    if (!capability.readyFor(platform)) {
      return NativeQualificationRunResult(
        platform: platform,
        status: 'BLOCKED',
        exitCode: null,
        failureCategory: capability.blockersFor(platform).join(','),
        outputDirectory: 'build/phase6a-benchmark/$platform',
      );
    }
    final candidates = capability.devices.where(
      (device) =>
          device.platform == platform && device.physical && device.supported,
    );
    final selected = requestedDeviceId == null
        ? candidates.firstOrNull
        : candidates
              .where((device) => device.commandId == requestedDeviceId)
              .firstOrNull;
    if (selected == null) {
      return NativeQualificationRunResult(
        platform: platform,
        status: 'BLOCKED',
        exitCode: null,
        failureCategory: 'qualified_device_not_found',
        outputDirectory: 'build/phase6a-benchmark/$platform',
      );
    }
    final target = 'integration_test/phase6a_${platform}_benchmark_test.dart';
    try {
      final result = await commandRunner.run(
        'flutter',
        [
          'drive',
          '--driver=test_driver/phase6a_benchmark_driver.dart',
          '--target=$target',
          '-d',
          selected.commandId,
          '--dart-define=PHASE6A_FLUTTER_VERSION=$flutterVersion',
        ],
        workingDirectory: mobileDirectory,
        environment: {'PHASE6A_PLATFORM_LABEL': platform},
      );
      return NativeQualificationRunResult(
        platform: platform,
        status: result.exitCode == 0 ? 'PASS' : 'BLOCKED',
        exitCode: result.exitCode,
        failureCategory: result.exitCode == 0
            ? null
            : 'flutter_drive_exit_nonzero',
        outputDirectory: 'build/phase6a-benchmark/$platform',
      );
    } on Object {
      return NativeQualificationRunResult(
        platform: platform,
        status: 'BLOCKED',
        exitCode: null,
        failureCategory: 'flutter_drive_unavailable',
        outputDirectory: 'build/phase6a-benchmark/$platform',
      );
    }
  }
}

class NativeQualificationEvidenceExporter {
  const NativeQualificationEvidenceExporter();

  Future<void> exportCapability(
    DeviceCapabilityReport report,
    Directory outputDirectory,
  ) async {
    await outputDirectory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await File(
      '${outputDirectory.path}/device-capability.json',
    ).writeAsString('${encoder.convert(report.toJson())}\n', flush: true);
  }

  Future<void> exportRun(
    NativeQualificationRunResult result,
    Directory outputDirectory,
  ) async {
    await outputDirectory.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await File(
      '${outputDirectory.path}/${result.platform}-run.json',
    ).writeAsString('${encoder.convert(result.toJson())}\n', flush: true);
  }
}
