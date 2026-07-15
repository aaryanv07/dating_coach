import 'dart:async';

import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/presentation/screenshot_drop_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ScreenshotImportScreen extends ConsumerWidget {
  const ScreenshotImportScreen({super.key});

  Future<void> _extract(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(conversationImportProvider.notifier)
        .extractScreenshots();
    if (success && context.mounted) context.push('/import/review');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationImportProvider);
    final controller = ref.read(conversationImportProvider.notifier);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(controller.cancel());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Chat screenshots')),
        body: ResponsiveContent(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Add screenshots in reading order.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Images stay temporary and are cleared after the reviewed conversation is saved.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              ScreenshotDropTarget(onSources: controller.addSources),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Choose screenshots',
                icon: Icons.photo_library_outlined,
                variant: AppButtonVariant.secondary,
                isLoading: state.isPreparingSources,
                onPressed: state.isBusy || state.isPreparingSources
                    ? null
                    : () => unawaited(controller.pickScreenshots()),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorState(
                  title: 'Check these screenshots',
                  message: state.errorMessage!,
                ),
              ],
              if (state.sources.isEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const AppEmptyState(
                  title: 'No screenshots yet',
                  message:
                      'Choose up to 10 images to prepare the conversation.',
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '${state.sources.length} screenshot${state.sources.length == 1 ? '' : 's'} ready',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final source in state.sources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: AppSpacing.sm,
                    leading: CircleAvatar(child: Text('${source.index + 1}')),
                    title: Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${(source.byteSize / 1024).ceil()} KB'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Move ${source.name} earlier',
                          onPressed: source.index == 0
                              ? null
                              : () => unawaited(
                                  controller.moveSource(source.id, -1),
                                ),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Move ${source.name} later',
                          onPressed: source.index == state.sources.length - 1
                              ? null
                              : () => unawaited(
                                  controller.moveSource(source.id, 1),
                                ),
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                        IconButton(
                          tooltip: 'Remove ${source.name}',
                          onPressed: () =>
                              unawaited(controller.removeSource(source.id)),
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.appColors.risk,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (state.isPreparingSources) ...[
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label:
                      'Preparing screenshots ${(state.progress * 100).round()} percent',
                  value: '${(state.progress * 100).round()}%',
                  child: LinearProgressIndicator(value: state.progress),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Preparing selected screenshots on this device...'),
              ],
              if (state.isBusy) ...[
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  label:
                      'Extracting conversation text ${(state.progress * 100).round()} percent',
                  value: '${(state.progress * 100).round()}%',
                  child: LinearProgressIndicator(value: state.progress),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Preparing messages for review...'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: controller.cancelExtraction,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel extraction'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Extract conversation',
                icon: Icons.document_scanner_outlined,
                isLoading: state.isBusy,
                onPressed:
                    state.sources.isEmpty ||
                        state.isBusy ||
                        state.isPreparingSources
                    ? null
                    : () => unawaited(_extract(context, ref)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
