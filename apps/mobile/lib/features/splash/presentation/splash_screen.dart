import 'dart:async';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final delay = AppMotion.duration(context, AppMotionSpeed.normal);
    unawaited(
      Future<void>.delayed(delay, () {
        if (mounted) context.go('/onboarding');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AppReveal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ConvoMark(size: 72),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppConfig.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Clearer conversations. Your call.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
