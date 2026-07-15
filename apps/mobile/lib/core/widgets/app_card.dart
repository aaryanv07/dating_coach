import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppCard extends ConsumerStatefulWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: AppMotion.duration(context, AppMotionSpeed.fast),
      curve: AppMotion.springCurve,
      child: Material(
        color: context.appColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: context.appColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  ref.read(hapticsProvider).selection();
                  widget.onTap!();
                },
          onHighlightChanged: widget.onTap == null
              ? null
              : (pressed) => setState(() => _pressed = pressed),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (widget.semanticLabel == null) return card;
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: card,
    );
  }
}
