import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppButtonVariant { primary, secondary, quiet }

class AppButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final callback = onPressed == null || isLoading
        ? null
        : () {
            ref.read(hapticsProvider).confirmation();
            onPressed!();
          };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox.square(
            dimension: AppSizes.iconSmall,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: AppSizes.iconSmall),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
        RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
    );

    final button = switch (variant) {
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
      width: expand ? double.infinity : null,
      child: button,
    );
    if (semanticLabel == null) return sized;

    return Semantics(
      button: true,
      enabled: callback != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: sized,
    );
  }
}
