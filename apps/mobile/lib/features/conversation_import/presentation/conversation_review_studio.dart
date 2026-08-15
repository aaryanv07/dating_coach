import 'dart:async';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
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

  String? _saveBlocker(ConversationImportState state) {
    if (state.title.trim().isEmpty) {
      return 'Add a conversation title before analyzing.';
    }
    if (!state.readiness.isReady) {
      final unresolved = state.readiness.checks
          .where(
            (check) => !check.passed && check.label != 'Timestamp availability',
          )
          .map((check) => check.label)
          .join(', ');
      return unresolved.isEmpty
          ? 'Check the highlighted messages before analyzing.'
          : 'Check these items before analyzing: $unresolved.';
    }
    if (!state.saveConsent) {
      return 'Choose “Keep this reviewed conversation” before continuing.';
    }
    return null;
  }

  String _saveLabel(ConversationImportState state) {
    if (state.title.trim().isEmpty) return 'Add a title to continue';
    if (!state.readiness.isReady) return 'Check highlighted messages';
    if (!state.saveConsent) return 'Confirm permission to continue';
    return 'Confirm and analyze';
  }

  void _showSaveFeedback(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('review-save-feedback'),
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  Future<void> _attemptSave(BuildContext context, WidgetRef ref) async {
    final current = ref.read(conversationImportProvider);
    final blocker = _saveBlocker(current);
    if (blocker != null) {
      _showSaveFeedback(context, blocker);
      return;
    }

    final saved = await ref.read(conversationImportProvider.notifier).save();
    if (!context.mounted) return;
    if (saved != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      context.go('/conversations/${saved.id}/coach-preview');
      return;
    }
    final error = ref.read(conversationImportProvider).errorMessage;
    _showSaveFeedback(
      context,
      error ?? 'The conversation could not be saved. Try again.',
    );
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
    final saveBlocker = _saveBlocker(state);
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
            backgroundColor: Colors.transparent,
            title: AppGradientText(
              'Review conversation',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
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
          body: AppVibrantBackdrop(
            child: state.events.isEmpty
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
                        const _ReviewIntro(),
                        const SizedBox(height: AppSpacing.xl),
                        TextFormField(
                          key: const Key('conversation-title-field'),
                          initialValue: state.title,
                          onChanged: controller.setTitle,
                          textCapitalization: TextCapitalization.sentences,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            labelText: 'Conversation title',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppDepthReveal(
                          child: _ReadinessPanel(report: state.readiness),
                        ),
                        if (state.extractionWarnings.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          _StudioPanel(
                            semanticLabel: 'Items to check before analysis',
                            accent: context.appColors.caution,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _RoundIcon(
                                      icon: Icons.fact_check_outlined,
                                      color: context.appColors.caution,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        'A few things need your check',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                for (final warning in state.extractionWarnings)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
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
                                        Expanded(
                                          child: Text(
                                            _reviewWarningCopy(warning.code),
                                          ),
                                        ),
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
                            title: 'This conversation is not ready to analyze',
                            message: state.errorMessage!,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        _EventCountHeader(
                          eventCount: state.events
                              .where((event) => !event.isDeleted)
                              .length,
                          messageCount: state.events
                              .where((event) => event.countsAsMessage)
                              .length,
                          onAdd: () => unawaited(_addMessage(context, ref)),
                        ),
                        const SizedBox(height: AppSpacing.md),
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
                        _StudioPanel(
                          child: CheckboxListTile(
                            key: const Key('save-consent-checkbox'),
                            contentPadding: EdgeInsets.zero,
                            value: state.saveConsent,
                            onChanged: (value) =>
                                controller.setSaveConsent(value ?? false),
                            title: const Text(
                              'Keep this reviewed conversation',
                            ),
                            subtitle: const Text(
                              'Keep the reviewed messages in ELLIS so you can analyze them now and revisit them later. Original screenshots are deleted.',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SaveRequirementNotice(
                          message: saveBlocker,
                          isReady: saveBlocker == null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ReviewPrimaryAction(
                          child: AppButton(
                            key: const Key('confirm-save-button'),
                            label: _saveLabel(state),
                            icon: Icons.check_rounded,
                            isLoading: state.isBusy,
                            onPressed: state.isBusy
                                ? null
                                : () => unawaited(_attemptSave(context, ref)),
                            semanticLabel: _saveLabel(state),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

String _reviewWarningCopy(ExtractionWarningCode code) => switch (code) {
  ExtractionWarningCode.confidenceUnavailable =>
    'Some text may need a closer look. Compare anything uncertain with the original screenshot.',
  ExtractionWarningCode.screenshotOrderAdjusted =>
    'We adjusted the screenshot order automatically. Check that the conversation flows naturally.',
  ExtractionWarningCode.screenshotOrderUncertain =>
    'We are not fully sure about the screenshot order. Check that the conversation flows naturally.',
  ExtractionWarningCode.timelineGap =>
    'There may be a gap between screenshots. Add any missing messages you notice.',
  ExtractionWarningCode.duplicateOverlapRemoved =>
    'We removed repeated content where screenshots overlapped. Check that the join looks right.',
  ExtractionWarningCode.unknownSpeaker =>
    'Confirm who sent the highlighted messages.',
  ExtractionWarningCode.eventReviewRequired =>
    'Check the highlighted reactions or non-message items.',
};

class _ReviewIntro extends StatelessWidget {
  const _ReviewIntro();

  @override
  Widget build(BuildContext context) {
    return AppReveal(
      child: Column(
        key: const Key('premium-review-intro'),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: context.appColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: AppSizes.iconSmall,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Flexible(child: Text('Private review • You decide')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppGradientText(
            'Make sure we got it right',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 36,
              height: 1.04,
              letterSpacing: -1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Read through the conversation and correct anything that looks wrong. ELLIS handles the technical setup underneath.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.appColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EventCountHeader extends StatelessWidget {
  const _EventCountHeader({
    required this.eventCount,
    required this.messageCount,
    required this.onAdd,
  });

  final int eventCount;
  final int messageCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conversation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                eventCount == messageCount
                    ? '$messageCount messages'
                    : '$messageCount messages • ${eventCount - messageCount} other items',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Add missing message',
          onPressed: onAdd,
          icon: const Icon(Icons.add_comment_rounded),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.minimumTouchTarget,
      height: AppSizes.minimumTouchTarget,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({
    required this.child,
    this.semanticLabel,
    this.accent,
    super.key,
  });

  final Widget child;
  final String? semanticLabel;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panel = Material(
      color: context.appColors.surfaceRaised.withValues(alpha: 0.94),
      elevation: 3,
      shadowColor: (accent ?? theme.colorScheme.primary).withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.hero,
        side: BorderSide(
          color: accent?.withValues(alpha: 0.42) ?? context.appColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
    if (semanticLabel == null) return panel;
    return Semantics(container: true, label: semanticLabel, child: panel);
  }
}

class _ReviewPrimaryAction extends StatelessWidget {
  const _ReviewPrimaryAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('review-premium-primary-action'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SaveRequirementNotice extends StatelessWidget {
  const _SaveRequirementNotice({required this.message, required this.isReady});

  final String? message;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final color = isReady
        ? context.appColors.success
        : context.appColors.caution;
    return Semantics(
      liveRegion: true,
      label: message ?? 'Conversation is ready to analyze',
      child: AnimatedContainer(
        key: const Key('review-save-requirement'),
        duration: AppMotion.duration(context, AppMotionSpeed.fast),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: color.withValues(alpha: 0.36)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isReady
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: AppSizes.iconSmall,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message ?? 'Everything looks ready. You can analyze now.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
    final statusColor = report.isReady
        ? context.appColors.success
        : context.appColors.caution;
    final checksToReview = report.checks
        .where(
          (check) => !check.passed && check.label != 'Timestamp availability',
        )
        .map((check) => check.label)
        .toList(growable: false);
    return _StudioPanel(
      key: const Key('premium-readiness-panel'),
      accent: statusColor,
      child: Semantics(
        container: true,
        label: report.isReady
            ? 'Conversation is ready to analyze after confirmation.'
            : 'Conversation needs review before analysis.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoundIcon(
                  icon: report.isReady
                      ? Icons.verified_rounded
                      : Icons.tune_rounded,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    report.isReady
                        ? 'Ready to analyze'
                        : 'Check highlighted messages',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              report.isReady
                  ? 'We prepared the message order and speaker labels. Give the conversation one quick read, then continue.'
                  : checksToReview.isEmpty
                  ? 'Review the highlighted items below before continuing.'
                  : 'Please check: ${checksToReview.join(', ')}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              key: const Key('data-quality-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
              title: const Text('Review details'),
              subtitle: const Text('Optional data-quality information'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Data quality ${report.score}%. This is not a relationship, interest, compatibility, or success score.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
      return _StudioPanel(
        accent: context.appColors.risk,
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

    return _StudioPanel(
      semanticLabel:
          'Event ${widget.position + 1}, ${message.eventType.label}, '
          '${message.speaker.label}${message.needsReview ? ', needs review' : ''}',
      accent: message.needsReview ? context.appColors.caution : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_eventIcon(message.eventType), size: AppSizes.iconSmall),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message.eventType.countsAsMessage
                      ? message.speaker.label
                      : message.eventType.label,
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
          if (!message.eventType.isStructural) ...[
            DropdownButtonFormField<MessageSpeaker>(
              key: Key('speaker-${message.id}'),
              initialValue: message.speaker,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Who sent this?'),
              items: MessageSpeaker.values
                  .where((speaker) => speaker != MessageSpeaker.system)
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
            const SizedBox(height: AppSpacing.sm),
          ],
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
              labelText: 'Message',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
          ExpansionTile(
            key: Key('message-details-${message.id}'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Message details'),
            subtitle: const Text('Optional advanced correction'),
            children: [
              DropdownButtonFormField<ConversationEventType>(
                key: Key('event-type-${message.id}'),
                initialValue: message.eventType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item type'),
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
              const SizedBox(height: AppSpacing.sm),
            ],
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
