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

/// Adds bounded depth to important state changes without blocking interaction.
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

/// Briefly clarifies root-tab changes and becomes static for reduced motion.
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
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
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

/// Gently floats the child up and down forever — great for orbs and marks.
class AppFloat extends StatefulWidget {
  const AppFloat({
    required this.child,
    this.amplitude = 10,
    this.duration = const Duration(seconds: 5),
    super.key,
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<AppFloat> createState() => _AppFloatState();
}

class _AppFloatState extends State<AppFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(AppFloat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
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
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, widget.amplitude * (t * 2 - 1)),
          child: child,
        );
      },
    );
  }
}

/// Continuously rotates the child — for gradient halos and rings.
class AppSlowRotate extends StatefulWidget {
  const AppSlowRotate({
    required this.child,
    this.duration = const Duration(seconds: 8),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppSlowRotate> createState() => _AppSlowRotateState();
}

class _AppSlowRotateState extends State<AppSlowRotate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(AppSlowRotate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
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
    return RotationTransition(turns: _controller, child: widget.child);
  }
}

/// Sweeps a soft highlight across the child forever — shimmer effect.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    required this.child,
    this.duration = const Duration(milliseconds: 2200),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller
          ..stop()
          ..forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
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
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + t * 4, 0),
              end: Alignment(0 + t * 4, 0),
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// Scales down slightly while pressed — tactile feedback for taps.
class AppTapScale extends StatefulWidget {
  const AppTapScale({
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<AppTapScale> createState() => _AppTapScaleState();
}

class _AppTapScaleState extends State<AppTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MotionScope.reduceMotionOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: !reduce && _pressed ? widget.pressedScale : 1,
        duration: reduce ? Duration.zero : AppDurations.fast,
        curve: AppMotion.standardCurve,
        child: widget.child,
      ),
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
