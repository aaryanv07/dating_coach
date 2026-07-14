import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConvoCoachApp extends ConsumerStatefulWidget {
  const ConvoCoachApp({this.router, super.key});

  final GoRouter? router;

  @override
  ConsumerState<ConvoCoachApp> createState() => _ConvoCoachAppState();
}

class _ConvoCoachAppState extends ConsumerState<ConvoCoachApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final motionPreference = ref.watch(motionPreferenceProvider);
    final reduceMotion = motionPreference == MotionPreference.reduced;

    return MaterialApp.router(
      title: AppConfig.name,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: reduceMotion
          ? Duration.zero
          : AppDurations.normal,
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) {
        final systemReduced =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        return MotionScope(
          reduceMotion: reduceMotion || systemReduced,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
