import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

class AppStateView extends StatelessWidget {
  const AppStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    expand: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends AppStateView {
  const AppEmptyState({
    required super.title,
    required super.message,
    super.actionLabel,
    super.onAction,
    super.key,
  }) : super(icon: Icons.chat_bubble_outline_rounded);
}

class AppErrorState extends AppStateView {
  const AppErrorState({
    required super.title,
    required super.message,
    super.actionLabel,
    super.onAction,
    super.key,
  }) : super(icon: Icons.error_outline_rounded);
}

class AppOfflineState extends AppStateView {
  const AppOfflineState({
    super.title = 'You are offline',
    super.message = 'Reconnect to continue. Nothing private was uploaded.',
    super.actionLabel,
    super.onAction,
    super.key,
  }) : super(icon: Icons.cloud_off_outlined);
}
