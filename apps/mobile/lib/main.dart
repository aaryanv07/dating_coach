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
    AppConfig.validateForStartup(releaseMode: kReleaseMode);
  } on MobileConfigurationError {
    runApp(const ConvoCoachConfigurationErrorApp());
    return;
  }
  await initializeDateFormatting();
  runApp(const ProviderScope(child: ConvoCoachApp()));
}
