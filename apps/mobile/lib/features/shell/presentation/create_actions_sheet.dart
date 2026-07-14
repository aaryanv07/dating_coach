import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:flutter/material.dart';

enum _CreateAction { analyse, firstMessage }

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
              semanticLabel: 'Analyse a conversation',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CreateAction.analyse),
              child: const _ActionRow(
                icon: Icons.forum_outlined,
                title: 'Analyse a conversation',
                subtitle: 'Understand balance, momentum and next steps.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              semanticLabel: 'Create a first message',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CreateAction.firstMessage),
              child: const _ActionRow(
                icon: Icons.edit_note_rounded,
                title: 'Create a first message',
                subtitle:
                    'Start from real profile context, not a generic line.',
              ),
            ),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  final isAnalysis = action == _CreateAction.analyse;
  await showAppDialog(
    context: context,
    title: isAnalysis
        ? 'Conversation tools are next'
        : 'Profile tools are next',
    message: isAnalysis
        ? 'This foundation does not read or analyse conversations yet.'
        : 'This foundation does not upload profiles or generate messages yet.',
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
