import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Glass-style card with a subtle gradient surface and glowing border on tap.
class AppCard extends ConsumerStatefulWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.highlight = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  /// When true the card is drawn with the brand gradient border and glow.
  final bool highlight;

  @override
  ConsumerState<AppCard> createState() => _AppCardState();
}

class _AppCardState extends ConsumerState<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final decoration = BoxDecoration(
      gradient: isDark
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.surfaceRaised,
                Color.lerp(colors.surfaceRaised, colors.gradientEnd, 0.06)!,
              ],
            )
          : null,
      color: isDark ? null : colors.surfaceRaised,
      borderRadius: AppRadii.card,
      border: Border.all(
        color: widget.highlight ? colors.glassBorder : colors.border,
        width: widget.highlight ? 1.5 : 1,
      ),
      boxShadow: widget.highlight
          ? [
              BoxShadow(
                color: colors.glow,
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );

    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: AppMotion.duration(context, AppMotionSpeed.fast),
      curve: AppMotion.springCurve,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: AppRadii.card,
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
