import 'dart:async';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
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
      appBar: AppBar(title: const Text('Import conversation')),
      body: ResponsiveContent(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            const SizedBox(height: AppSpacing.lg),
            AppReveal(
              child: Text(
                'Bring the conversation into focus.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing is interpreted until you review and confirm every message.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              semanticLabel: 'Import chat screenshots',
              onTap: () => unawaited(
                _open(context, ref, ConversationImportType.screenshot),
              ),
              child: const _ImportRow(
                icon: Icons.photo_library_outlined,
                title: 'Chat screenshots',
                subtitle:
                    'Choose several images and correct the extracted text.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              semanticLabel: 'Paste a conversation',
              onTap: () =>
                  unawaited(_open(context, ref, ConversationImportType.paste)),
              child: const _ImportRow(
                icon: Icons.content_paste_rounded,
                title: 'Paste conversation',
                subtitle: 'Add message text directly, one message per line.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Opacity(
              opacity: AppOpacity.disabled,
              child: AppCard(
                child: _ImportRow(
                  icon: Icons.account_box_outlined,
                  title: 'Profile screenshot',
                  subtitle: 'Coming in a future phase.',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const AppOfflineState(
              title: 'Prepared on this device',
              message:
                  'Screenshot extraction uses a replaceable on-device mock in this phase. Source images are temporary.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.arrow_forward_rounded),
      ],
    );
  }
}
