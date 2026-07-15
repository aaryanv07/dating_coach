import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _CreateAction { importConversation, profileScreenshot }

Future<void> showCreateActions(BuildContext context) async {
  final action = await showAppBottomSheet<_CreateAction>(
    context: context,
    builder: (sheetContext) {
      return AppBottomSheetBody(
        title: 'What would help right now?',
        subtitle:
            'Choose a starting point. You will always review what happens next.',
        child: Column(
          children: [
            AppCard(
              semanticLabel: 'Import a conversation',
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_CreateAction.importConversation),
              child: const _ActionRow(
                icon: Icons.forum_outlined,
                title: 'Import conversation',
                subtitle: 'Prepare screenshots or pasted text for review.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              semanticLabel: 'Profile screenshot, coming in a future phase',
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(_CreateAction.profileScreenshot),
              child: const _ActionRow(
                icon: Icons.edit_note_rounded,
                title: 'Profile screenshot',
                subtitle: 'Reserved for a future phase.',
              ),
            ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  if (action == _CreateAction.importConversation) {
    context.push('/import');
    return;
  }
  await showAppDialog(
    context: context,
    title: 'Profile tools are next',
    message: 'This phase does not upload profiles or generate messages.',
    primaryLabel: 'Got it',
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
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
