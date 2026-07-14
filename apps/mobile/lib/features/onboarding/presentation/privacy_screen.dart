import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: AppButton(
                label: 'I understand',
                icon: Icons.arrow_forward_rounded,
                semanticLabel: 'Continue after privacy introduction',
                onPressed: () => context.go('/age'),
              ),
            ),
          ),
        ),
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'Privacy protected',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Private by design.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your conversations stay under your control. Sharing is always a deliberate action.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _PrivacyPoint(
              icon: Icons.touch_app_outlined,
              title: 'You choose what enters',
              body:
                  'No background message reading, scraping or automatic sending.',
            ),
            const _PrivacyPoint(
              icon: Icons.delete_outline_rounded,
              title: 'Minimal by default',
              body:
                  'Future imports will be removable and screenshots will not be kept indefinitely.',
            ),
            const _PrivacyPoint(
              icon: Icons.psychology_alt_outlined,
              title: 'Coaching, not certainty',
              body:
                  'Signals are explained as patterns, never proof of another person\'s intent.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.appColors.info, size: AppSizes.iconMedium),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
