import 'dart:async';

import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/shell/presentation/create_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: conversations.when(
        loading: () => const _ConversationListSkeleton(),
        error: (error, stackTrace) => AppErrorState(
          title: 'Conversations are unavailable.',
          message: 'Try loading your private list again.',
          actionLabel: 'Retry',
          onAction: () =>
              unawaited(ref.read(conversationListProvider.notifier).refresh()),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(
                title: 'A quiet start.',
                message:
                    'Saved conversations appear here only after you choose to keep them.',
                actionLabel: 'Create',
                onAction: () => unawaited(showCreateActions(context)),
              )
            : _ConversationList(items: items),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.items});

  final List<ConversationSummary> items;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ConversationSummary conversation,
  ) async {
    final confirmed = await showAppDialog(
      context: context,
      title: 'Delete this conversation?',
      message: 'This removes the saved conversation and cannot be undone.',
      primaryLabel: 'Delete',
      secondaryLabel: 'Keep',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await ref
        .read(conversationListProvider.notifier)
        .deleteConversation(conversation.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Conversation deleted.'
              : 'Conversation could not be deleted.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: ref.read(conversationListProvider.notifier).refresh,
      child: ResponsiveContent(
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          itemCount: items.length + 1,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'Saved only with your permission',
                style: Theme.of(context).textTheme.labelMedium,
              );
            }
            final conversation = items[index - 1];
            return AppCard(
              semanticLabel: 'Open ${conversation.title}',
              onTap: () => context.push('/conversations/${conversation.id}'),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    conversation.participantName.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(conversation.title),
                subtitle: Text(
                  '${conversation.participantName} · ${conversation.messageCount} messages',
                ),
                trailing: IconButton(
                  tooltip: 'Delete ${conversation.title}',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () =>
                      unawaited(_delete(context, ref, conversation)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveContent(
      child: Column(
        children: [
          AppSkeleton(height: 88),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 88),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 88),
        ],
      ),
    );
  }
}
