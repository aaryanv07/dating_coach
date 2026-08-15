import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/configuration_error_app.dart';
import 'package:convo_coach/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => MobileReleasePlatform.android,
      TargetPlatform.iOS => MobileReleasePlatform.ios,
      _ => MobileReleasePlatform.all,
    };
    AppConfig.validateForStartup(releaseMode: kReleaseMode, platform: platform);
  } on MobileConfigurationError {
    runApp(const ConvoCoachConfigurationErrorApp());
    return;
  }
  await initializeDateFormatting();
  runApp(const ProviderScope(child: ConvoCoachApp()));
}
