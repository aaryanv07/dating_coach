import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppButtonVariant { primary, secondary, quiet }

/// Vibrant gradient-filled button with a soft glow for the primary variant,
/// outlined glass for secondary, and text-only for quiet.
class AppButton extends ConsumerStatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.isLoading = false,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;
  final bool isLoading;
  final String? semanticLabel;

  @override
  ConsumerState<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends ConsumerState<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _handleTap() {
    ref.read(hapticsProvider).confirmation();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    final (
      Color foreground,
      Gradient? gradient,
      Color? background,
      BorderSide? border,
      List<BoxShadow>? shadows,
    ) = switch (widget.variant) {
      AppButtonVariant.primary => (
        scheme.onPrimary,
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.gradientStart, colors.gradientEnd],
        ),
        null,
        null,
        _enabled
            ? [
                BoxShadow(
                  color: colors.glow,
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      AppButtonVariant.secondary => (
        scheme.primary,
        null,
        colors.glassBackground,
        BorderSide(color: colors.glassBorder, width: 1.5),
        null,
      ),
      AppButtonVariant.quiet => (
        colors.textMuted,
        null,
        Colors.transparent,
        null,
        null,
      ),
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox.square(
            dimension: AppSizes.iconSmall,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: AppSizes.iconSmall, color: foreground),
        if (widget.isLoading || widget.icon != null)
          const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(color: foreground),
          ),
        ),
      ],
    );

    final button = AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: AppMotion.duration(context, AppMotionSpeed.fast),
      curve: AppMotion.springCurve,
      child: AnimatedOpacity(
        duration: AppMotion.duration(context, AppMotionSpeed.fast),
        opacity: _enabled ? 1 : AppOpacity.disabled,
        child: Container(
          height: AppSizes.buttonHeight,
          constraints: const BoxConstraints(
            minWidth: AppSizes.minimumTouchTarget,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            color: background,
            borderRadius: AppRadii.button,
            border: border == null ? null : Border.fromBorderSide(border),
            boxShadow: shadows,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: AppRadii.button,
              onTap: _enabled ? _handleTap : null,
              onHighlightChanged: _enabled
                  ? (pressed) => setState(() => _pressed = pressed)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Center(
                  widthFactor: widget.expand ? null : 1,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final sized = widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(child: sized),
    );
  }
}
