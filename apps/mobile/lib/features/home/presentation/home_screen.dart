import 'dart:async';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/shell/presentation/create_actions_sheet.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.xxl,
              ),
              children: [
                const AppReveal(child: BrandLockup(compact: true)),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 60),
                  child: AppShimmer(
                    duration: const Duration(milliseconds: 3200),
                    child: GradientText(
                      'Level up your\nconversations.',
                      gradient: LinearGradient(
                        colors: [colors.gradientStart, colors.gradientEnd],
                      ),
                      style: textTheme.displaySmall,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppReveal(
                  delay: const Duration(milliseconds: 140),
                  child: Text(
                    'Start with context, stay authentic and keep the final call yours.',
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 200),
                  child: AppCard(
                    highlight: true,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.gradientStart,
                                colors.gradientEnd,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(color: colors.glow, blurRadius: 20),
                            ],
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Bring one conversation into focus.',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Import a chat and get calm, explainable guidance in seconds.',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Start creating',
                          icon: Icons.auto_awesome_rounded,
                          onPressed:
                              () => unawaited(showCreateActions(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 260),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: colors.success),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Private preview mode',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                AppConfig.mockMode
                                    ? 'No conversation data leaves this app in the current mock experience.'
                                    : 'Review privacy settings before sharing conversation data.',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppReveal(
                  delay: const Duration(milliseconds: 320),
                  child: Text('Your space', style: textTheme.titleLarge),
                ),
                const SizedBox(height: AppSpacing.md),
                AppReveal(
                  delay: const Duration(milliseconds: 380),
                  child: AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.inbox_outlined, color: colors.textMuted),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'No conversations saved. Nothing is stored without a clear choice.',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
