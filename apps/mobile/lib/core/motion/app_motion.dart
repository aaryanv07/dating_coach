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
