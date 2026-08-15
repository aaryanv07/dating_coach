import 'dart:convert';
import 'dart:io';

import '../benchmark/phase6a/device_capability.dart';
import '../benchmark/phase6a/native_qualification_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runNativeQualification(arguments);
}

Future<int> runNativeQualification(List<String> arguments) async {
  final platform = _option(arguments, 'platform') ?? 'all';
  final requestedDeviceId = _option(arguments, 'device-id');
  if (!const {'all', 'android', 'ios'}.contains(platform)) {
    stderr.writeln('Unsupported --platform. Use all, android, or ios.');
    return 64;
  }
  if (requestedDeviceId != null && platform == 'all') {
    stderr.writeln('--device-id requires a single --platform.');
    return 64;
  }
  final detector = NativeDeviceCapabilityDetector(
    environment: Platform.environment,
  );
  final capability = await detector.detect();
  const exporter = NativeQualificationEvidenceExporter();
  final readinessDirectory = Directory('build/phase6a-readiness');
  await exporter.exportCapability(capability, readinessDirectory);
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(capability.toJson()),
  );

  final platforms = platform == 'all' ? const ['android', 'ios'] : [platform];
  final flutterVersion = capability.tools
      .where((tool) => tool.id == 'flutter')
      .map((tool) => tool.version)
      .firstOrNull;
  var allPassed = true;
  for (final selectedPlatform in platforms) {
    final result = await const NativeQualificationRunner().run(
      platform: selectedPlatform,
      capability: capability,
      mobileDirectory: Directory.current.path,
      requestedDeviceId: requestedDeviceId,
      flutterVersion: flutterVersion ?? 'unreported',
    );
    await exporter.exportRun(result, readinessDirectory);
    stdout.writeln(jsonEncode(result.toJson()));
    if (result.status != 'PASS') allPassed = false;
  }
  return allPassed ? 0 : 2;
}

String? _option(List<String> arguments, String name) {
  final prefix = '--$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}
