import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    required this.height,
    this.width = double.infinity,
    super.key,
  });

  final double height;
  final double width;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.loadingPulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.reduceMotionOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
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
    final base = context.appColors.border.withValues(alpha: 0.45);
    final highlight = context.appColors.border.withValues(alpha: 0.82);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(base, highlight, _controller.value),
                borderRadius: AppRadii.card,
              ),
              child: SizedBox(width: widget.width, height: widget.height),
            );
          },
        ),
      ),
    );
  }
}
