import 'dart:convert';
import 'dart:io';

class QualificationCommandResult {
  const QualificationCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class QualificationCommandRunner {
  Future<QualificationCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  });
}

class ProcessQualificationCommandRunner implements QualificationCommandRunner {
  const ProcessQualificationCommandRunner();

  @override
  Future<QualificationCommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: true,
    );
    return QualificationCommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}

class QualificationToolCapability {
  const QualificationToolCapability({
    required this.id,
    required this.available,
    required this.version,
  });

  final String id;
  final bool available;
  final String? version;

  Map<String, Object?> toJson() => {
    'id': id,
    'available': available,
    'version': version,
  };
}

class QualificationDevice {
  const QualificationDevice({
    required this.commandId,
    required this.platform,
    required this.targetPlatform,
    required this.emulator,
    required this.supported,
    required this.sdk,
  });

  /// Used only to target `flutter drive`; never serialized into evidence.
  final String commandId;
  final String platform;
  final String targetPlatform;
  final bool emulator;
  final bool supported;
  final String? sdk;

  bool get physical => !emulator;

  Map<String, Object?> toJson() => {
    'platform': platform,
    'target_platform': targetPlatform,
    'emulator': emulator,
    'physical': physical,
    'supported': supported,
    'sdk': sdk,
  };
}

class DeviceCapabilityReport {
  const DeviceCapabilityReport({
    required this.generatedAt,
    required this.tools,
    required this.devices,
    required this.androidReady,
    required this.iosReady,
    required this.androidBlockers,
    required this.iosBlockers,
  });

  final DateTime generatedAt;
  final List<QualificationToolCapability> tools;
  final List<QualificationDevice> devices;
  final bool androidReady;
  final bool iosReady;
  final List<String> androidBlockers;
  final List<String> iosBlockers;

  String get status => androidReady || iosReady ? 'PASS' : 'BLOCKED';

  bool readyFor(String platform) => switch (platform) {
    'android' => androidReady,
    'ios' => iosReady,
    _ => false,
  };

  List<String> blockersFor(String platform) => switch (platform) {
    'android' => androidBlockers,
    'ios' => iosBlockers,
    _ => const ['unsupported_platform'],
  };

  QualificationDevice? firstPhysicalDevice(String platform) {
    for (final device in devices) {
      if (device.platform == platform && device.physical && device.supported) {
        return device;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'schema_version': 'phase6a-device-readiness.v1',
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'status': status,
    'platforms': {
      'android': {
        'status': androidReady ? 'PASS' : 'BLOCKED',
        'blockers': androidBlockers,
      },
      'ios': {'status': iosReady ? 'PASS' : 'BLOCKED', 'blockers': iosBlockers},
    },
    'tools': tools.map((tool) => tool.toJson()).toList(),
    'devices': devices.map((device) => device.toJson()).toList(),
  };
}

class NativeDeviceCapabilityDetector {
  const NativeDeviceCapabilityDetector({
    this.commandRunner = const ProcessQualificationCommandRunner(),
    this.environment = const {},
    this.clock = DateTime.now,
  });

  final QualificationCommandRunner commandRunner;
  final Map<String, String> environment;
  final DateTime Function() clock;

  Future<DeviceCapabilityReport> detect() async {
    final flutter = await _probe('flutter', const ['--version', '--machine']);
    final adb = await _probe('adb', const ['version']);
    final xcode = await _probe('xcodebuild', const ['-version']);
    final cocoaPods = await _probe('pod', const ['--version']);
    final devicesResult = await _probe('flutter', const [
      'devices',
      '--machine',
    ], retainOutput: true);
    final devices = devicesResult.available
        ? parseFlutterDevices(devicesResult.output ?? '')
        : const <QualificationDevice>[];
    final sdkConfigured =
        [environment['ANDROID_HOME'], environment['ANDROID_SDK_ROOT']]
            .whereType<String>()
            .map((value) => value.trim())
            .any((path) => path.isNotEmpty && Directory(path).existsSync());
    final androidSdkAvailable = sdkConfigured || adb.available;
    final physicalAndroid = devices.any(
      (device) =>
          device.platform == 'android' && device.physical && device.supported,
    );
    final physicalIos = devices.any(
      (device) =>
          device.platform == 'ios' && device.physical && device.supported,
    );
    final androidBlockers = <String>[
      if (!flutter.available) 'flutter_unavailable',
      if (!androidSdkAvailable) 'android_sdk_unavailable',
      if (!physicalAndroid) 'physical_android_device_unavailable',
    ];
    final iosBlockers = <String>[
      if (!flutter.available) 'flutter_unavailable',
      if (!xcode.available) 'xcode_unavailable',
      if (!cocoaPods.available) 'cocoapods_unavailable',
      if (!physicalIos) 'physical_ios_device_unavailable',
    ];
    return DeviceCapabilityReport(
      generatedAt: clock(),
      tools: [
        QualificationToolCapability(
          id: 'flutter',
          available: flutter.available,
          version: _flutterVersion(flutter.output),
        ),
        QualificationToolCapability(
          id: 'android_sdk',
          available: androidSdkAvailable,
          version: adb.version,
        ),
        QualificationToolCapability(
          id: 'xcode',
          available: xcode.available,
          version: xcode.version,
        ),
        QualificationToolCapability(
          id: 'cocoapods',
          available: cocoaPods.available,
          version: cocoaPods.version,
        ),
      ],
      devices: List.unmodifiable(devices),
      androidReady: androidBlockers.isEmpty,
      iosReady: iosBlockers.isEmpty,
      androidBlockers: List.unmodifiable(androidBlockers),
      iosBlockers: List.unmodifiable(iosBlockers),
    );
  }

  List<QualificationDevice> parseFlutterDevices(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      final devices = <QualificationDevice>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final item = value.cast<String, Object?>();
        final id = item['id'];
        final target = item['targetPlatform'];
        if (id is! String || id.isEmpty || target is! String) continue;
        final platform = platformFamily(target);
        if (platform == null) continue;
        devices.add(
          QualificationDevice(
            commandId: id,
            platform: platform,
            targetPlatform: target,
            emulator: item['emulator'] == true,
            supported: item['isSupported'] != false,
            sdk: item['sdk'] is String ? item['sdk']! as String : null,
          ),
        );
      }
      return List.unmodifiable(devices);
    } on FormatException {
      return const [];
    }
  }

  String? platformFamily(String targetPlatform) {
    final value = targetPlatform.toLowerCase();
    if (value.startsWith('android')) return 'android';
    if (value.startsWith('ios')) return 'ios';
    return null;
  }

  Future<_ProbeResult> _probe(
    String executable,
    List<String> arguments, {
    bool retainOutput = false,
  }) async {
    try {
      final result = await commandRunner.run(executable, arguments);
      final available = result.exitCode == 0;
      final output = result.stdout.trim();
      return _ProbeResult(
        available: available,
        version: available ? _firstLine(output) : null,
        output: retainOutput || executable == 'flutter' ? output : null,
      );
    } on ProcessException {
      return const _ProbeResult(available: false);
    } on Object {
      return const _ProbeResult(available: false);
    }
  }

  String? _flutterVersion(String? output) {
    if (output == null || output.isEmpty) return null;
    try {
      final decoded = jsonDecode(output);
      if (decoded is Map && decoded['frameworkVersion'] is String) {
        return decoded['frameworkVersion']! as String;
      }
    } on FormatException {
      // A human-readable version still proves availability.
    }
    return _firstLine(output);
  }

  String? _firstLine(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\r?\n')).first;
  }
}

class _ProbeResult {
  const _ProbeResult({this.available = false, this.version, this.output});

  final bool available;
  final String? version;
  final String? output;
}
