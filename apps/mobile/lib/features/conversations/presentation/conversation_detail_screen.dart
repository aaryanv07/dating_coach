import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversations/application/conversation_detail_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationDetailScreen extends ConsumerWidget {
  const ConversationDetailScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationDetailProvider(conversationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Saved conversation')),
      body: conversation.when(
        loading: () => const ResponsiveContent(
          child: Column(
            children: [
              AppSkeleton(height: 120),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(height: 96),
            ],
          ),
        ),
        error: (error, stackTrace) => const AppErrorState(
          title: 'Conversation unavailable',
          message: 'The saved conversation could not be opened.',
        ),
        data: (detail) {
          if (detail == null) {
            return const AppEmptyState(
              title: 'No saved detail',
              message:
                  'Preview conversations do not contain private message text.',
            );
          }
          return ResponsiveContent(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${detail.messages.length} messages · ${detail.readinessScore}% data readiness',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final message in detail.messages) ...[
                  Align(
                    alignment: message.speaker == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.speaker == 'user'
                                  ? 'Me'
                                  : detail.participantName,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(message.text),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  'Original screenshots were deleted after confirmation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
