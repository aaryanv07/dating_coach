import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:flutter/material.dart';

class ConvoCoachConfigurationErrorApp extends StatelessWidget {
  const ConvoCoachConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: SafeArea(
          child: AppErrorState(
            title: 'This build needs configuration.',
            message:
                'Install a configured build before connecting an account or private conversation.',
          ),
        ),
      ),
    );
  }
}
