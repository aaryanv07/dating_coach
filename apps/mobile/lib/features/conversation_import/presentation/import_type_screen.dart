import 'dart:async';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ImportTypeScreen extends ConsumerWidget {
  const ImportTypeScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ConversationImportType type,
  ) async {
    await ref.read(conversationImportProvider.notifier).start(type);
    if (!context.mounted) return;
    context.push(
      type == ConversationImportType.screenshot
          ? '/import/screenshots'
          : '/import/paste',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a conversation'),
        backgroundColor: Colors.transparent,
      ),
      body: AppVibrantBackdrop(
        child: ResponsiveContent(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xxxl,
            ),
            children: [
              AppReveal(
                child: AppGradientText(
                  'CHOOSE THE\nEASIEST WAY.',
                  key: const Key('import-vibrant-headline'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You will review the conversation before anything is saved or analyzed.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppReveal(
                offset: const Offset(0, 8),
                child: AppCard(
                  key: const Key('import-screenshots-option'),
                  semanticLabel: 'Import chat screenshots',
                  onTap: () => unawaited(
                    _open(context, ref, ConversationImportType.screenshot),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: const _ImportOption(
                    icon: Icons.add_photo_alternate_rounded,
                    eyebrow: 'FASTEST',
                    title: 'Upload screenshots',
                    subtitle:
                        'Choose several chat images, then correct the extracted messages.',
                    prominent: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                key: const Key('import-paste-option'),
                semanticLabel: 'Paste a conversation',
                onTap: () => unawaited(
                  _open(context, ref, ConversationImportType.paste),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: const _ImportOption(
                  icon: Icons.content_paste_rounded,
                  eyebrow: 'NO SCREENSHOT NEEDED',
                  title: 'Paste conversation',
                  subtitle: 'Add message text directly, one message per line.',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Screenshot bytes stay temporary and on-device. Confirmed messages remain under your control.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.prominent = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: prominent
                  ? [scheme.primary, scheme.secondary]
                  : [scheme.tertiary, scheme.primary],
            ),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Icon(icon, color: scheme.onPrimary, size: 28),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: prominent ? scheme.secondary : scheme.tertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: AppSizes.minimumTouchTarget,
          height: AppSizes.minimumTouchTarget,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(Icons.arrow_forward_rounded, color: scheme.primary),
        ),
      ],
    );
  }
}
