import 'dart:async';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.reduceMotionOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.deliberate,
    );
    unawaited(_controller!.forward().whenComplete(_finish));
  }

  void _finish() {
    if (mounted) context.go('/onboarding');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const _SplashContent();
    }

    final markCurve = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, 0.7, curve: AppMotion.springCurve),
    );
    final signalCurve = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.15, 0.85, curve: AppMotion.standardCurve),
    );
    final copyCurve = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 1, curve: AppMotion.standardCurve),
    );

    return _SplashContent(
      markAnimation: markCurve,
      signalAnimation: signalCurve,
      copyAnimation: copyCurve,
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({
    this.markAnimation,
    this.signalAnimation,
    this.copyAnimation,
  });

  final Animation<double>? markAnimation;
  final Animation<double>? signalAnimation;
  final Animation<double>? copyAnimation;

  @override
  Widget build(BuildContext context) {
    final mark = _animated(
      animation: markAnimation,
      slideBegin: const Offset(0, 0.08),
      scaleBegin: 0.84,
      child: const ConvoMark(key: Key('splash-mark'), size: 76),
    );
    final signal = _animated(
      animation: signalAnimation,
      slideBegin: const Offset(-0.12, 0),
      scaleBegin: 0.94,
      child: const _ConversationSignal(),
    );
    final copy = _animated(
      animation: copyAnimation,
      slideBegin: const Offset(0, 0.14),
      scaleBegin: 0.98,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppConfig.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Clearer conversations. Your call.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );

    return Scaffold(
      body: AppVibrantBackdrop(
        animate: false,
        child: SafeArea(
          child: Center(
            child: Semantics(
              container: true,
              label: '${AppConfig.name}. Clearer conversations. Your call.',
              child: ExcludeSemantics(
                child: Column(
                  key: const Key('animated-splash-content'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mark,
                    const SizedBox(height: AppSpacing.md),
                    signal,
                    const SizedBox(height: AppSpacing.lg),
                    copy,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _animated({
    required Animation<double>? animation,
    required Offset slideBegin,
    required double scaleBegin,
    required Widget child,
  }) {
    if (animation == null) return child;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: slideBegin,
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: scaleBegin, end: 1).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

class _ConversationSignal extends StatelessWidget {
  const _ConversationSignal();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        key: const Key('splash-conversation-signal'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SignalBubble(width: 42, color: scheme.surfaceContainerHighest),
          const SizedBox(width: AppSpacing.sm),
          _SignalBubble(width: 56, color: scheme.primaryContainer),
          const SizedBox(width: AppSpacing.sm),
          _SignalBubble(width: 34, color: scheme.secondaryContainer),
        ],
      ),
    );
  }
}

class _SignalBubble extends StatelessWidget {
  const _SignalBubble({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.card),
      child: SizedBox(width: width, height: 18),
    );
  }
}
