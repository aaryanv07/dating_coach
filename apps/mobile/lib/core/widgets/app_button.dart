import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppButtonVariant { primary, secondary, quiet }

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

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final callback = widget.onPressed == null || widget.isLoading
        ? null
        : () {
            ref.read(hapticsProvider).confirmation();
            widget.onPressed!();
          };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          const SizedBox.square(
            dimension: AppSizes.iconSmall,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: AppSizes.iconSmall),
        if (widget.isLoading || widget.icon != null)
          const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppSizes.minimumTouchTarget, AppSizes.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadii.hero),
      ),
    );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      AppButtonVariant.quiet => TextButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
    };

    final sized = SizedBox(
      height: AppSizes.buttonHeight,
      width: widget.expand ? double.infinity : null,
      child: button,
    );
    final semanticButton = widget.semanticLabel == null
        ? sized
        : Semantics(
            button: true,
            enabled: callback != null,
            label: widget.semanticLabel,
            excludeSemantics: true,
            child: sized,
          );

    final enabled = callback != null;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: enabled && _pressed ? 0.98 : 1,
        duration: AppMotion.duration(context, AppMotionSpeed.fast),
        curve: AppMotion.springCurve,
        child: semanticButton,
      ),
    );
  }
}
