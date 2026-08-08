import 'dart:async';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
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
    final delay = AppMotion.duration(context, AppMotionSpeed.deliberate);
    unawaited(
      Future<void>.delayed(delay * 2, () {
        if (mounted) context.go('/onboarding');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppPopIn(
                  child: AppAmbientPulse(
                    child: const ConvoMark(size: 88, glow: true),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 120),
                  child: GradientText(
                    AppConfig.name,
                    gradient: LinearGradient(
                      colors: [colors.gradientStart, colors.gradientEnd],
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppReveal(
                  delay: const Duration(milliseconds: 220),
                  child: Text(
                    'Clearer conversations. Your call.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
