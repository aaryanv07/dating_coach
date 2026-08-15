import 'dart:async';
import 'dart:math' as math;

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/authentication/domain/authentication_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    final delay = AppMotion.duration(context, AppMotionSpeed.deliberate);
    unawaited(_resolveLaunchDestination(delay * 2));
  }

  Future<void> _resolveLaunchDestination(Duration minimumDelay) async {
    final results = await Future.wait<Object?>([
      Future<void>.delayed(minimumDelay),
      ref
          .read(authenticationGatewayProvider)
          .watchSession()
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => const MobileAuthenticationSession.signedOut(),
          )
          .catchError((_) => const MobileAuthenticationSession.signedOut()),
    ]);
    if (!mounted) return;
    final session = results[1] as MobileAuthenticationSession;
    context.go(session.isAuthenticated ? '/profile/setup' : '/onboarding');
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
                  child: SizedBox(
                    width: 144,
                    height: 144,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AppSlowRotate(
                          child: _GradientHalo(
                            size: 144,
                            colors: [
                              colors.gradientStart,
                              colors.gradientEnd,
                              colors.gradientStart,
                            ],
                          ),
                        ),
                        AppAmbientPulse(
                          child: const ConvoMark(size: 88, glow: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 120),
                  child: AppShimmer(
                    child: GradientText(
                      AppConfig.name,
                      gradient: LinearGradient(
                        colors: [colors.gradientStart, colors.gradientEnd],
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
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
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 320),
                  child: _PulseDots(color: colors.gradientEnd),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft rotating conic-gradient ring used as a halo behind the brand mark.
class _GradientHalo extends StatelessWidget {
  const _GradientHalo({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [for (final color in colors) color.withValues(alpha: 0.55)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three dots pulsing in sequence — a subtle "warming up" indicator.
class _PulseDots extends StatefulWidget {
  const _PulseDots({required this.color});

  final Color color;

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) {
      return const SizedBox(height: 8);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _dot(_controller.value, i),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(double t, int index) {
    // Smooth periodic pulse: each dot is phase-offset by a third of a cycle.
    final phase = (t - index / 3) * 2 * math.pi;
    final active = 0.5 + 0.5 * math.sin(phase);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: 0.3 + 0.7 * active),
      ),
    );
  }
}
