import 'dart:async';

import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
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
  editTimestamp,
  attachRelationship,
  detachRelationship,
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
                        .where(
                          (value) =>
                              value != MessageSpeaker.unknown &&
                              value != MessageSpeaker.system,
                        )
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
          body: state.events.isEmpty
              ? const AppErrorState(
                  title: 'No conversation events to review',
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
                              '${state.events.where((event) => !event.isDeleted).length} events · '
                              '${state.events.where((event) => event.countsAsMessage).length} messages',
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
                        index < state.events.length;
                        index++
                      ) ...[
                        _ReviewMessageBlock(
                          key: ValueKey(state.events[index].id),
                          message: state.events[index],
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
                          'Only the reviewed event sequence, normalized message projection, and source-deletion metadata are kept.',
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
      case _MessageAction.editTimestamp:
        await _showTimestampDialog();
      case _MessageAction.attachRelationship:
        await _showRelationshipDialog();
      case _MessageAction.detachRelationship:
        controller.detachEventRelationship(widget.message.id);
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

  Future<void> _showTimestampDialog() async {
    final visibleController = TextEditingController(
      text: widget.message.visibleTimestampText ?? '',
    );
    DateTime? timestamp = widget.message.timestamp;
    final result = await showDialog<(DateTime?, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Correct timestamp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: visibleController,
                decoration: const InputDecoration(
                  labelText: 'Visible timestamp text',
                  hintText: 'For example, 8:20 PM',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      timestamp == null
                          ? 'No resolved date and time'
                          : timestamp!.toLocal().toString(),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: timestamp?.toLocal() ?? DateTime.now(),
                      );
                      if (selectedDate == null || !dialogContext.mounted) {
                        return;
                      }
                      final selectedTime = await showTimePicker(
                        context: dialogContext,
                        initialTime: timestamp == null
                            ? TimeOfDay.now()
                            : TimeOfDay.fromDateTime(timestamp!.toLocal()),
                      );
                      if (selectedTime == null) return;
                      setDialogState(() {
                        timestamp = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        ).toUtc();
                      });
                    },
                    child: const Text('Choose'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop((null, null)),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                timestamp,
                visibleController.text.trim().isEmpty
                    ? null
                    : visibleController.text.trim(),
              )),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    visibleController.dispose();
    if (result != null) {
      ref
          .read(conversationImportProvider.notifier)
          .changeTimestamp(
            widget.message.id,
            timestamp: result.$1,
            visibleText: result.$2,
          );
    }
  }

  Future<void> _showRelationshipDialog() async {
    final state = ref.read(conversationImportProvider);
    final targets = state.events
        .where(
          (event) =>
              event.id != widget.message.id &&
              !event.isDeleted &&
              !event.eventType.isStructural &&
              event.eventType != ConversationEventType.reaction,
        )
        .toList(growable: false);
    if (targets.isEmpty) return;
    final targetId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Attach to event'),
        children: [
          for (final target in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(target.id),
              child: Text(
                '${target.eventType.label}: '
                '${target.text.trim().isEmpty ? 'No visible text' : target.text}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    if (targetId != null) {
      ref
          .read(conversationImportProvider.notifier)
          .attachEventRelationship(widget.message.id, targetId);
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
                'Deleted ${message.eventType.label.toLowerCase()}: ${message.text}',
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
          'Event ${widget.position + 1}, ${message.eventType.label}, '
          '${message.speaker.label}${message.needsReview ? ', needs review' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_eventIcon(message.eventType), size: AppSizes.iconSmall),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message.eventType.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (!message.eventType.countsAsMessage)
                const Chip(label: Text('Not counted as a message')),
              PopupMenuButton<_MessageAction>(
                tooltip: 'Edit event actions',
                onSelected: (action) => unawaited(_performAction(action)),
                itemBuilder: (context) => _actionItems(message),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ConversationEventType>(
                  key: Key('event-type-${message.id}'),
                  initialValue: message.eventType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: ConversationEventType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (type) {
                    if (type != null) {
                      ref
                          .read(conversationImportProvider.notifier)
                          .changeEventType(message.id, type);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<MessageSpeaker>(
                  key: Key('speaker-${message.id}'),
                  initialValue: message.speaker,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Speaker'),
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
            ],
          ),
          if (message.needsReview)
            Semantics(
              label:
                  'Needs review because event type, speaker, relationship, or extraction evidence is uncertain',
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
                    Expanded(
                      child: Text(
                        message.eventType == ConversationEventType.unknown
                            ? 'Unknown item — choose an event type'
                            : 'Needs review',
                      ),
                    ),
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
            enabled: message.eventType.supportsTextEditing,
            onSubmitted: (text) => ref
                .read(conversationImportProvider.notifier)
                .editMessage(message.id, text),
            decoration: const InputDecoration(
              labelText: 'Visible event text',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
          if (message.relationshipTargetId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Semantics(
                label:
                    '${message.eventType.label} attached to event ${message.relationshipTargetId}',
                child: Chip(
                  avatar: const Icon(Icons.link_rounded),
                  label: Text('Attached to ${message.relationshipTargetId}'),
                ),
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

List<PopupMenuEntry<_MessageAction>> _actionItems(ReviewMessage event) {
  return [
    if (event.eventType == ConversationEventType.textMessage) ...const [
      PopupMenuItem(
        value: _MessageAction.merge,
        child: Text('Merge with next'),
      ),
      PopupMenuItem(value: _MessageAction.split, child: Text('Split event')),
    ],
    const PopupMenuItem(
      value: _MessageAction.swapSpeaker,
      child: Text('Swap speaker'),
    ),
    const PopupMenuItem(
      value: _MessageAction.editTimestamp,
      child: Text('Correct timestamp'),
    ),
    if (event.eventType.supportsRelationship)
      const PopupMenuItem(
        value: _MessageAction.attachRelationship,
        child: Text('Attach to event'),
      ),
    if (event.relationships.isNotEmpty)
      const PopupMenuItem(
        value: _MessageAction.detachRelationship,
        child: Text('Detach relationship'),
      ),
    const PopupMenuItem(
      value: _MessageAction.duplicate,
      child: Text('Duplicate'),
    ),
    const PopupMenuItem(value: _MessageAction.moveUp, child: Text('Move up')),
    const PopupMenuItem(
      value: _MessageAction.moveDown,
      child: Text('Move down'),
    ),
    const PopupMenuItem(value: _MessageAction.delete, child: Text('Delete')),
  ];
}

IconData _eventIcon(ConversationEventType type) => switch (type) {
  ConversationEventType.textMessage => Icons.chat_bubble_outline_rounded,
  ConversationEventType.emojiMessage => Icons.emoji_emotions_outlined,
  ConversationEventType.reaction => Icons.favorite_outline_rounded,
  ConversationEventType.image => Icons.image_outlined,
  ConversationEventType.video => Icons.videocam_outlined,
  ConversationEventType.gif => Icons.gif_box_outlined,
  ConversationEventType.sticker => Icons.sticky_note_2_outlined,
  ConversationEventType.voiceNote => Icons.mic_none_rounded,
  ConversationEventType.audio => Icons.audio_file_outlined,
  ConversationEventType.document => Icons.description_outlined,
  ConversationEventType.link => Icons.link_rounded,
  ConversationEventType.location => Icons.location_on_outlined,
  ConversationEventType.contactCard => Icons.contact_page_outlined,
  ConversationEventType.poll => Icons.poll_outlined,
  ConversationEventType.paymentRequest => Icons.payments_outlined,
  ConversationEventType.callStarted => Icons.call_outlined,
  ConversationEventType.callEnded => Icons.call_end_outlined,
  ConversationEventType.missedCall => Icons.phone_missed_outlined,
  ConversationEventType.declinedCall => Icons.phone_disabled_outlined,
  ConversationEventType.deletedMessage => Icons.comments_disabled_outlined,
  ConversationEventType.editedMessageMarker => Icons.edit_note_rounded,
  ConversationEventType.replyReference => Icons.reply_rounded,
  ConversationEventType.systemMessage => Icons.info_outline_rounded,
  ConversationEventType.dateSeparator => Icons.calendar_today_outlined,
  ConversationEventType.unreadSeparator => Icons.mark_chat_unread_outlined,
  ConversationEventType.encryptionNotice => Icons.lock_outline_rounded,
  ConversationEventType.memberEvent => Icons.group_outlined,
  ConversationEventType.unknown => Icons.help_outline_rounded,
};
