import 'dart:io';

import 'run_phase6a2_native.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runNativeQualification(['--platform=android', ...arguments]);
}
