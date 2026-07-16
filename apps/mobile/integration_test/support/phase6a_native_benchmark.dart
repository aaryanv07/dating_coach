import 'dart:io';

import 'package:convo_coach/features/conversation_import/data/google_mlkit_text_recognition_provider.dart';
import 'package:convo_coach/features/conversation_import/data/image_preprocessor.dart';
import 'package:convo_coach/features/conversation_import/data/real_conversation_ocr_engine.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../benchmark/phase6a/benchmark_harness.dart';
import '../../benchmark/phase6a/benchmark_session.dart';
import '../../benchmark/phase6a/fixture_catalog.dart';

void runPhase6aNativeBenchmark({required String expectedPlatform}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Phase 6A native extraction benchmark',
    (tester) async {
      expect(Platform.operatingSystem, expectedPlatform);
      await initializeDateFormatting();
      final fixtures = await BenchmarkFixtureCatalog.load();
      final device = await _readDeviceEnvironment();
      final provider = GoogleMlKitTextRecognitionProvider();
      final engine = RealConversationOcrEngine(
        preprocessor: const SafeConversationImagePreprocessor(),
        textRecognitionProvider: provider,
      );
      const harness = ExtractionBenchmarkHarness();
      final report = await harness.run(
        fixtures: fixtures,
        engineFactory: (_) => engine,
        sessionEnvironment: BenchmarkSessionEnvironment(
          platform: Platform.operatingSystem,
          deviceModel: device.model,
          osVersion: device.osVersion,
          flutterVersion: const String.fromEnvironment(
            'PHASE6A_FLUTTER_VERSION',
            defaultValue: 'unreported',
          ),
          mlKitVersion: provider.providerVersion,
          extractionVersion: engine.extractionVersion,
        ),
        nativeDeviceRun: device.isPhysicalDevice,
      );
      binding.reportData = <String, Object?>{'phase6a': report.toJson()};

      expect(report.cases, hasLength(fixtures.length));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<_NativeDeviceEnvironment> _readDeviceEnvironment() async {
  final plugin = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final info = await plugin.androidInfo;
    return _NativeDeviceEnvironment(
      model: info.model,
      osVersion: 'Android ${info.version.release}',
      isPhysicalDevice: info.isPhysicalDevice,
    );
  }
  if (Platform.isIOS) {
    final info = await plugin.iosInfo;
    return _NativeDeviceEnvironment(
      model: info.modelName,
      osVersion: '${info.systemName} ${info.systemVersion}',
      isPhysicalDevice: info.isPhysicalDevice,
    );
  }
  throw UnsupportedError(
    'Phase 6A native benchmark supports Android and iOS only.',
  );
}

class _NativeDeviceEnvironment {
  const _NativeDeviceEnvironment({
    required this.model,
    required this.osVersion,
    required this.isPhysicalDevice,
  });

  final String model;
  final String osVersion;
  final bool isPhysicalDevice;
}
