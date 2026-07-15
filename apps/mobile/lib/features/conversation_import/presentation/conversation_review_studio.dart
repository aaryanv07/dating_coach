import 'dart:async';

import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/readiness.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _MessageAction {
  merge,
  split,
  swapSpeaker,
  duplicate,
  moveUp,
  moveDown,
  delete,
}

class ConversationReviewStudio extends ConsumerWidget {
  const ConversationReviewStudio({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final saved = await ref.read(conversationImportProvider.notifier).save();
    if (saved != null && context.mounted) context.go('/conversations');
  }

  Future<void> _addMessage(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    var speaker = MessageSpeaker.me;
    final result = await showDialog<(String, MessageSpeaker)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add missing message'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<MessageSpeaker>(
                    initialValue: speaker,
                    decoration: const InputDecoration(labelText: 'Speaker'),
                    items: MessageSpeaker.values
                        .where((value) => value != MessageSpeaker.unknown)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => speaker = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('add-message-field'),
                    controller: textController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      Navigator.of(
                        dialogContext,
                      ).pop((textController.text.trim(), speaker));
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
    textController.dispose();
    if (result != null) {
      ref
          .read(conversationImportProvider.notifier)
          .addMessage(text: result.$1, speaker: result.$2);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationImportProvider);
    final controller = ref.read(conversationImportProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            controller.redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): controller.redo,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Review studio'),
            actions: [
              IconButton(
                tooltip: 'Undo',
                constraints: const BoxConstraints(
                  minWidth: AppSizes.minimumTouchTarget,
                  minHeight: AppSizes.minimumTouchTarget,
                ),
                onPressed: state.canUndo ? controller.undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Redo',
                constraints: const BoxConstraints(
                  minWidth: AppSizes.minimumTouchTarget,
                  minHeight: AppSizes.minimumTouchTarget,
                ),
                onPressed: state.canRedo ? controller.redo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: 'Conversation actions',
                onSelected: (action) {
                  if (action == 'swap') controller.swapAllSpeakers();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'swap',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.swap_vert_rounded),
                      title: Text('Swap all speakers'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: state.messages.isEmpty
              ? const AppErrorState(
                  title: 'No messages to review',
                  message: 'Return to import and add a conversation first.',
                )
              : ResponsiveContent(
                  maxWidth: 840,
                  child: ListView(
                    key: const Key('review-message-list'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const Key('conversation-title-field'),
                        initialValue: state.title,
                        onChanged: controller.setTitle,
                        textCapitalization: TextCapitalization.sentences,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          labelText: 'Conversation title',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ReadinessPanel(report: state.readiness),
                      if (state.extractionWarnings.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          semanticLabel: 'Extraction review notes',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extraction review notes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final warning in state.extractionWarnings)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: AppSizes.iconSmall,
                                        color: context.appColors.caution,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: Text(warning.message)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppErrorState(
                          title: 'This conversation is not ready to save',
                          message: state.errorMessage!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${state.messages.where((message) => !message.isDeleted).length} message blocks',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add missing message',
                            onPressed: () =>
                                unawaited(_addMessage(context, ref)),
                            icon: const Icon(Icons.add_comment_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (
                        var index = 0;
                        index < state.messages.length;
                        index++
                      ) ...[
                        _ReviewMessageBlock(
                          key: ValueKey(state.messages[index].id),
                          message: state.messages[index],
                          position: index,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(
                        label: 'Add message',
                        icon: Icons.add_rounded,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => unawaited(_addMessage(context, ref)),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      CheckboxListTile(
                        key: const Key('save-consent-checkbox'),
                        contentPadding: EdgeInsets.zero,
                        value: state.saveConsent,
                        onChanged: (value) =>
                            controller.setSaveConsent(value ?? false),
                        title: const Text('Save this reviewed conversation'),
                        subtitle: const Text(
                          'Only normalized message text and source-deletion metadata are kept.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        key: const Key('confirm-save-button'),
                        label: 'Confirm and save',
                        icon: Icons.check_rounded,
                        isLoading: state.isBusy,
                        onPressed:
                            state.readiness.isReady &&
                                state.saveConsent &&
                                state.title.trim().isNotEmpty &&
                                !state.isBusy
                            ? () => unawaited(_save(context, ref))
                            : null,
                        semanticLabel:
                            'Confirm and save reviewed conversation, readiness ${state.readiness.score} percent',
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.report});

  final ReadinessReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Semantics(
        container: true,
        label:
            'Conversation readiness ${report.score} percent. This measures data quality only.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.isReady ? 'Conversation ready' : 'Review needed',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${report.score}%',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: report.score / 100),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Data quality only. This is not a relationship or success score.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Column(
              children: [
                for (final check in report.checks) ...[
                  Semantics(
                    label:
                        '${check.label}: ${check.passed ? 'ready' : 'needs review'}',
                    child: Row(
                      children: [
                        Icon(
                          check.passed
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          size: AppSizes.iconSmall,
                          color: check.passed
                              ? context.appColors.success
                              : context.appColors.caution,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(check.label)),
                        Text('${check.points}/${check.maximum}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMessageBlock extends ConsumerStatefulWidget {
  const _ReviewMessageBlock({
    required this.message,
    required this.position,
    super.key,
  });

  final ReviewMessage message;
  final int position;

  @override
  ConsumerState<_ReviewMessageBlock> createState() =>
      _ReviewMessageBlockState();
}

class _ReviewMessageBlockState extends ConsumerState<_ReviewMessageBlock> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.message.text);
    _focusNode = FocusNode()..addListener(_commitWhenFocusLeaves);
  }

  @override
  void didUpdateWidget(_ReviewMessageBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _textController.text != widget.message.text) {
      _textController.text = widget.message.text;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_commitWhenFocusLeaves)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _commitWhenFocusLeaves() {
    if (!_focusNode.hasFocus && _textController.text != widget.message.text) {
      ref
          .read(conversationImportProvider.notifier)
          .editMessage(widget.message.id, _textController.text);
    }
  }

  Future<void> _performAction(_MessageAction action) async {
    final controller = ref.read(conversationImportProvider.notifier);
    switch (action) {
      case _MessageAction.merge:
        controller.mergeWithNext(widget.message.id);
      case _MessageAction.split:
        await _showSplitDialog();
      case _MessageAction.swapSpeaker:
        controller.swapSpeaker(widget.message.id);
      case _MessageAction.duplicate:
        controller.duplicateMessage(widget.message.id);
      case _MessageAction.moveUp:
        controller.moveMessage(widget.message.id, -1);
      case _MessageAction.moveDown:
        controller.moveMessage(widget.message.id, 1);
      case _MessageAction.delete:
        controller.deleteMessage(widget.message.id);
    }
  }

  Future<void> _showSplitDialog() async {
    final midpoint = widget.message.text.length ~/ 2;
    final firstController = TextEditingController(
      text: widget.message.text.substring(0, midpoint).trim(),
    );
    final secondController = TextEditingController(
      text: widget.message.text.substring(midpoint).trim(),
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Split message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('split-first-field'),
              controller: firstController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'First message'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('split-second-field'),
              controller: secondController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Second message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop((firstController.text, secondController.text)),
            child: const Text('Split'),
          ),
        ],
      ),
    );
    firstController.dispose();
    secondController.dispose();
    if (result != null) {
      ref
          .read(conversationImportProvider.notifier)
          .splitMessageInto(
            widget.message.id,
            first: result.$1,
            second: result.$2,
          );
    }
  }

  Future<void> _viewOriginal() async {
    final sourceIndex = widget.message.sourceScreenshotIndex;
    if (sourceIndex == null) return;
    final importState = ref.read(conversationImportProvider);
    final sourceMetadata = importState.sources
        .where((source) => source.index == sourceIndex)
        .firstOrNull;
    if (sourceMetadata == null) return;
    final source = await ref
        .read(temporarySourceStoreProvider)
        .read(sourceMetadata.id);
    if (!mounted) return;
    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => AppBottomSheetBody(
        title: 'Screenshot ${sourceIndex + 1}',
        subtitle: sourceMetadata.name,
        child: Semantics(
          image: true,
          label: 'Original screenshot ${sourceIndex + 1}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: source?.bytes == null
                ? const _OriginalUnavailable()
                : Image.memory(
                    source!.bytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const _OriginalUnavailable(),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message.isDeleted) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Deleted message: ${message.text}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => ref
                  .read(conversationImportProvider.notifier)
                  .restoreMessage(message.id),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore'),
            ),
          ],
        ),
      );
    }

    return AppCard(
      semanticLabel:
          'Message ${widget.position + 1}, ${message.speaker.label}${message.needsReview ? ', needs review' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MessageSpeaker>(
                    key: Key('speaker-${message.id}'),
                    value: message.speaker,
                    isExpanded: true,
                    items: MessageSpeaker.values
                        .map(
                          (speaker) => DropdownMenuItem(
                            value: speaker,
                            child: Text(speaker.label),
                          ),
                        )
                        .toList(),
                    onChanged: (speaker) {
                      if (speaker != null) {
                        ref
                            .read(conversationImportProvider.notifier)
                            .changeSpeaker(message.id, speaker);
                      }
                    },
                  ),
                ),
              ),
              PopupMenuButton<_MessageAction>(
                tooltip: 'Edit message actions',
                onSelected: (action) => unawaited(_performAction(action)),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _MessageAction.merge,
                    child: Text('Merge with next'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.split,
                    child: Text('Split message'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.swapSpeaker,
                    child: Text('Swap speaker'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.duplicate,
                    child: Text('Duplicate'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.moveUp,
                    child: Text('Move up'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.moveDown,
                    child: Text('Move down'),
                  ),
                  PopupMenuItem(
                    value: _MessageAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          if (message.needsReview)
            Semantics(
              label: 'Needs review because OCR confidence is below 80 percent',
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: AppSizes.iconSmall,
                      color: context.appColors.caution,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Expanded(child: Text('Needs review')),
                  ],
                ),
              ),
            ),
          TextField(
            key: Key('message-${message.id}'),
            controller: _textController,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (text) => ref
                .read(conversationImportProvider.notifier)
                .editMessage(message.id, text),
            decoration: const InputDecoration(
              labelText: 'Message text',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
          Row(
            children: [
              if (message.timestamp != null)
                Expanded(
                  child: Text(
                    '${message.timestampEstimated ? 'Estimated ' : ''}${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(message.timestamp!))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                Expanded(
                  child: message.visibleTimestampText == null
                      ? const SizedBox.shrink()
                      : Text(
                          'Visible time ${message.visibleTimestampText}; date unavailable',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              if (message.sourceScreenshotIndex != null)
                TextButton.icon(
                  onPressed: _viewOriginal,
                  icon: const Icon(Icons.image_outlined),
                  label: Text('Original ${message.sourceScreenshotIndex! + 1}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OriginalUnavailable extends StatelessWidget {
  const _OriginalUnavailable();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      title: 'Preview unavailable',
      message: 'The message still keeps its source screenshot number.',
    );
  }
}
