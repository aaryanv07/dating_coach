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

  static Duration duration(BuildContext context, AppMotionSpeed speed) {
    if (MotionScope.reduceMotionOf(context)) return Duration.zero;
    return switch (speed) {
      AppMotionSpeed.fast => AppDurations.fast,
      AppMotionSpeed.normal => AppDurations.normal,
      AppMotionSpeed.deliberate => AppDurations.deliberate,
    };
  }
}

class AppReveal extends StatelessWidget {
  const AppReveal({
    required this.child,
    this.offset = const Offset(0, 12),
    super.key,
  });

  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) return child;

    return TweenAnimationBuilder<double>(
      duration: AppMotion.duration(context, AppMotionSpeed.normal),
      curve: AppMotion.standardCurve,
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

class AppDepthReveal extends StatelessWidget {
  const AppDepthReveal({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) return child;

    return TweenAnimationBuilder<double>(
      key: const Key('app-depth-reveal-animation'),
      duration: AppMotion.duration(context, AppMotionSpeed.deliberate),
      curve: AppMotion.springCurve,
      tween: Tween<double>(begin: 0, end: 1),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(0.035 * (1 - value)),
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: 0.985 + (0.015 * value),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppTabTransition extends StatefulWidget {
  const AppTabTransition({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<AppTabTransition> createState() => _AppTabTransitionState();
}

class _AppTabTransitionState extends State<AppTabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.normal,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standardCurve,
  );
  late final Animation<Offset> _position = Tween<Offset>(
    begin: const Offset(0.018, 0),
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.duration(context, AppMotionSpeed.normal);
    if (MotionScope.reduceMotionOf(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (MotionScope.reduceMotionOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reduceMotionOf(context)) {
      return KeyedSubtree(
        key: const Key('tab-transition-static'),
        child: widget.child,
      );
    }
    return FadeTransition(
      key: const Key('tab-transition-motion'),
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}
