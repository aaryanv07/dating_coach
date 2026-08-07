import 'dart:async';

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/presentation/screenshot_drop_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ScreenshotImportScreen extends ConsumerWidget {
  const ScreenshotImportScreen({super.key});

  Future<void> _prepare(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(conversationImportProvider.notifier)
        .extractScreenshots();
    if (success && context.mounted) context.push('/import/review');
  }

  Future<void> _pickAndPrepare(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(conversationImportProvider.notifier);
    final sourceCount = ref.read(conversationImportProvider).sources.length;
    await controller.pickScreenshots();
    if (!context.mounted) return;
    final next = ref.read(conversationImportProvider);
    if (next.sources.length > sourceCount && next.errorMessage == null) {
      await _prepare(context, ref);
    }
  }

  Future<void> _addAndPrepare(
    BuildContext context,
    WidgetRef ref,
    List<TemporaryImportSource> sources,
  ) async {
    final controller = ref.read(conversationImportProvider.notifier);
    final sourceCount = ref.read(conversationImportProvider).sources.length;
    await controller.addSources(sources);
    if (!context.mounted) return;
    final next = ref.read(conversationImportProvider);
    if (next.sources.length > sourceCount && next.errorMessage == null) {
      await _prepare(context, ref);
    }
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
        appBar: AppBar(title: const Text('Add screenshots')),
        body: ResponsiveContent(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Upload the chat. We’ll prepare the rest.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose up to 10 screenshots. ConvoCoach prepares the message order and speaker suggestions on this device, then takes you straight to review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              _AnimatedScreenshotStack(count: state.sources.length),
              const SizedBox(height: AppSpacing.lg),
              ScreenshotDropTarget(
                onSources: (sources) => _addAndPrepare(context, ref, sources),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const Key('upload-screenshots-button'),
                label: 'Upload screenshots',
                icon: Icons.photo_library_outlined,
                variant: AppButtonVariant.secondary,
                isLoading: state.isPreparingSources,
                onPressed: state.isBusy || state.isPreparingSources
                    ? null
                    : () => unawaited(_pickAndPrepare(context, ref)),
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
                  title: 'Ready when you are',
                  message:
                      'Upload screenshots and ConvoCoach will open the conversation review automatically.',
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '${state.sources.length} screenshot${state.sources.length == 1 ? '' : 's'} selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ExpansionTile(
                  key: const Key('upload-details'),
                  enabled: !state.isBusy && !state.isPreparingSources,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Review upload details'),
                  subtitle: const Text(
                    'Only change this if the screenshots were selected out of order.',
                  ),
                  children: [
                    for (final source in state.sources)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: AppSpacing.sm,
                        leading: CircleAvatar(
                          child: Text('${source.index + 1}'),
                        ),
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
                              onPressed: state.isBusy || source.index == 0
                                  ? null
                                  : () => unawaited(
                                      controller.moveSource(source.id, -1),
                                    ),
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                            IconButton(
                              tooltip: 'Move ${source.name} later',
                              onPressed:
                                  state.isBusy ||
                                      source.index == state.sources.length - 1
                                  ? null
                                  : () => unawaited(
                                      controller.moveSource(source.id, 1),
                                    ),
                              icon: const Icon(Icons.arrow_downward_rounded),
                            ),
                            IconButton(
                              tooltip: 'Remove ${source.name}',
                              onPressed: state.isBusy
                                  ? null
                                  : () => unawaited(
                                      controller.removeSource(source.id),
                                    ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: context.appColors.risk,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                      'Preparing conversation ${(state.progress * 100).round()} percent',
                  value: '${(state.progress * 100).round()}%',
                  child: LinearProgressIndicator(value: state.progress),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Reading the chat, suggesting speakers, and putting the conversation in order…',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: controller.cancelExtraction,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel preparation'),
                  ),
                ),
              ],
              if (state.sources.isNotEmpty &&
                  state.errorMessage != null &&
                  !state.isBusy) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Try preparation again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => unawaited(_prepare(context, ref)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedScreenshotStack extends StatelessWidget {
  const _AnimatedScreenshotStack({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleCount = count.clamp(0, 3);
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: count == 0
          ? 'Synthetic screenshot stack. No screenshots selected.'
          : 'Synthetic screenshot stack. $count screenshots selected.',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            key: const Key('animated-screenshot-stack'),
            width: 320,
            height: 142,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('screenshot-stack-$visibleCount'),
              duration: AppMotion.duration(context, AppMotionSpeed.deliberate),
              curve: AppMotion.springCurve,
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _ScreenshotCard(
                      color: scheme.tertiaryContainer,
                      offset: Offset(-58 * value, 4 * value),
                      angle: -0.095 * value,
                    ),
                    _ScreenshotCard(
                      color: scheme.primaryContainer,
                      offset: Offset(0, -8 * value),
                      angle: 0,
                    ),
                    _ScreenshotCard(
                      color: scheme.secondaryContainer,
                      offset: Offset(58 * value, 5 * value),
                      angle: 0.095 * value,
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: context.appColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          count == 0 ? 'READY WHEN YOU ARE' : '$count READY',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: scheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  const _ScreenshotCard({
    required this.color,
    required this.offset,
    required this.angle,
  });

  final Color color;
  final Offset offset;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 112,
          height: 118,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(
              color: scheme.surface.withValues(alpha: 0.82),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ScreenshotLine(width: 72, color: scheme.surface),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: _ScreenshotLine(
                  width: 58,
                  color: scheme.surface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ScreenshotLine(
                width: 66,
                color: scheme.surface.withValues(alpha: 0.86),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotLine extends StatelessWidget {
  const _ScreenshotLine({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
    );
  }
}
