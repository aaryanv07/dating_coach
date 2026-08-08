import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

enum AppMotionSpeed { fast, normal, deliberate }

class MotionScope extends InheritedWidget {
  const MotionScope({
    required this.reduceMotion,
    required super.child,
    super.key,
  });

  final bool reduceMotion;

  static bool reduceMotionOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    final systemDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return (scope?.reduceMotion ?? false) || systemDisabled;
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) {
    return reduceMotion != oldWidget.reduceMotion;
  }
}

abstract final class AppMotion {
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve bounceCurve = Curves.elasticOut;

  static Duration duration(BuildContext context, AppMotionSpeed speed) {
    if (MotionScope.reduceMotionOf(context)) return Duration.zero;
    return switch (speed) {
      AppMotionSpeed.fast => AppDurations.fast,
      AppMotionSpeed.normal => AppDurations.normal,
      AppMotionSpeed.deliberate => AppDurations.deliberate,
    };
  }
}

/// Fades and slides content into view.
class AppReveal extends StatelessWidget {
  const AppReveal({
    required this.child,
    this.offset = const Offset(0, 16),
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Offset offset;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) return child;

    final duration = AppMotion.duration(context, AppMotionSpeed.normal);
    return TweenAnimationBuilder<double>(
      duration: duration + delay,
      curve: Interval(
        delay == Duration.zero
            ? 0
            : delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: AppMotion.standardCurve,
      ),
      tween: Tween<double>(begin: 0, end: 1),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offset.dx * (1 - value), offset.dy * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Pops content in with a springy scale — great for hero marks and icons.
class AppPopIn extends StatelessWidget {
  const AppPopIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) return child;

    return TweenAnimationBuilder<double>(
      duration: AppMotion.duration(context, AppMotionSpeed.deliberate),
      curve: AppMotion.springCurve,
      tween: Tween<double>(begin: 0.6, end: 1),
      child: child,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value.clamp(0, 1), child: child),
        );
      },
    );
  }
}

/// Slowly pulses opacity/scale forever — ambient glow effects.
class AppAmbientPulse extends StatefulWidget {
  const AppAmbientPulse({
    required this.child,
    this.minScale = 0.96,
    this.maxScale = 1.04,
    super.key,
  });

  final Widget child;
  final double minScale;
  final double maxScale;

  @override
  State<AppAmbientPulse> createState() => _AppAmbientPulseState();
}

class _AppAmbientPulseState extends State<AppAmbientPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) return widget.child;
    return ScaleTransition(
      scale: Tween<double>(
        begin: widget.minScale,
        end: widget.maxScale,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Staggers reveals of a list of children.
class AppStaggeredColumn extends StatelessWidget {
  const AppStaggeredColumn({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.stepMilliseconds = 70,
    super.key,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final int stepMilliseconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++)
          AppReveal(
            delay: Duration(milliseconds: stepMilliseconds * i),
            child: children[i],
          ),
      ],
    );
  }
}
