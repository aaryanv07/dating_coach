import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversations/domain/conversation_summary.dart';
import 'package:convo_coach/features/progress/application/progress_dashboard_controller.dart';
import 'package:convo_coach/features/progress/domain/progress_journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  Future<void> _recordOutcome(
    BuildContext context,
    WidgetRef ref,
    OverallProgressDashboard dashboard,
  ) async {
    final outcome = await showModalBottomSheet<ConversationOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OutcomeSheet(dashboard: dashboard),
    );
    if (outcome == null || !context.mounted) return;
    final saved = await ref
        .read(progressDashboardProvider.notifier)
        .recordOutcome(outcome);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Your overall stats are updated.'
              : 'The outcome could not be saved.',
        ),
      ),
    );
  }

  Future<void> _editReflection(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private reflection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A note for you—not an assessment of anyone else. It stays in protected app storage.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('private-reflection-field'),
              controller: controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What do you want to remember?',
                hintText: 'I felt most like myself when…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save privately'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    final saved = await ref
        .read(progressDashboardProvider.notifier)
        .savePrivateReflection(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Private reflection saved.'
              : 'Reflection could not be saved.',
        ),
      ),
    );
  }

  Future<void> _clearJournal(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear private stats?'),
        content: const Text(
          'This removes every reply outcome, self-rating and private reflection from this device. Saved conversations are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear private stats'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(progressDashboardProvider.notifier).clearJournal();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(progressDashboardProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overall stats'),
        actions: [
          IconButton(
            tooltip: 'About these stats',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Signals, not predictions'),
                content: const Text(
                  'Your score uses only ratings and outcomes you record. It does not measure another person’s interest, compatibility, attraction or intent.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AppVibrantBackdrop(
        child: dashboard.when(
          loading: () => const _ProgressLoading(),
          error: (error, stackTrace) => AppErrorState(
            title: 'Your stats are unavailable.',
            message:
                'Protected progress data could not be loaded. Your conversations were not changed.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(progressDashboardProvider),
          ),
          data: (value) => _ProgressContent(
            dashboard: value,
            onRecordOutcome: () => _recordOutcome(context, ref, value),
            onEditReflection: () =>
                _editReflection(context, ref, value.journal.privateReflection),
            onClear: () => _clearJournal(context, ref),
          ),
        ),
      ),
    );
  }
}

class _ProgressLoading extends StatelessWidget {
  const _ProgressLoading();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      child: ListView(
        key: const Key('overall-stats-loading'),
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxxl,
        ),
        children: const [
          AppSkeleton(height: 54, width: 320),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(height: 250),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(height: 130),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(height: 180),
        ],
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.dashboard,
    required this.onRecordOutcome,
    required this.onEditReflection,
    required this.onClear,
  });

  final OverallProgressDashboard dashboard;
  final VoidCallback onRecordOutcome;
  final VoidCallback onEditReflection;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        key: const Key('overall-stats-list'),
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxxl,
        ),
        children: [
          Text(
            'YOUR WHOLE PICTURE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppReveal(
            child: AppGradientText(
              'Your progress,\nwithout the guesswork.',
              key: const Key('overall-stats-headline'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'One private dashboard across every conversation you choose to track.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ScoreHero(dashboard: dashboard),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            semanticLabel:
                'Score meaning. Self-reported communication only. Not interest or compatibility.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Self-reported communication only—never an interest, compatibility or date-success prediction.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _StatGrid(dashboard: dashboard),
          const SizedBox(height: AppSpacing.lg),
          _ReplyPerformanceCard(dashboard: dashboard),
          const SizedBox(height: AppSpacing.lg),
          _PlanStatusCard(dashboard: dashboard),
          const SizedBox(height: AppSpacing.lg),
          _ReflectionCard(
            reflection: dashboard.journal.privateReflection,
            onTap: onEditReflection,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const Key('record-outcome-action'),
            label: dashboard.hasConversations
                ? 'Update my outcomes'
                : 'Save a conversation first',
            icon: Icons.add_chart_rounded,
            onPressed: dashboard.hasConversations ? onRecordOutcome : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed:
                dashboard.recordedConversationCount > 0 ||
                    dashboard.journal.privateReflection.isNotEmpty
                ? onClear
                : null,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Clear private stats'),
          ),
        ],
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.dashboard});

  final OverallProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final score = dashboard.communicationScore;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: score == null
          ? 'Communication score not available. Record an outcome to begin.'
          : 'Your self-reported communication score is $score out of 100, based on ${dashboard.recordedConversationCount} recorded conversations.',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('overall-score-hero'),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.96),
                scheme.secondaryContainer.withValues(alpha: 0.9),
                scheme.tertiaryContainer.withValues(alpha: 0.86),
              ],
            ),
            borderRadius: AppRadii.hero,
            border: Border.all(color: context.appColors.border),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 440 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25;
              final gauge = _ScoreGauge(score: score);
              final copy = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNICATION SCORE',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    score == null
                        ? 'Add your first outcome'
                        : _scoreDescription(score),
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Authenticity • clarity • boundaries',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
              if (compact) {
                return Column(
                  children: [
                    gauge,
                    const SizedBox(height: AppSpacing.lg),
                    copy,
                  ],
                );
              }
              return Row(
                children: [
                  gauge,
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(child: copy),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _scoreDescription(int score) {
    if (score >= 85) return 'Feeling aligned';
    if (score >= 70) return 'Building consistency';
    if (score >= 50) return 'Finding your rhythm';
    return 'Room to reflect';
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final value = score ?? 0;
    final reduceMotion = MotionScope.reduceMotionOf(context);
    return TweenAnimationBuilder<double>(
      key: const Key('overall-score-animation'),
      duration: reduceMotion
          ? Duration.zero
          : AppMotion.duration(context, AppMotionSpeed.deliberate),
      curve: AppMotion.standardCurve,
      tween: Tween(
        begin: reduceMotion ? value.toDouble() : 0,
        end: value.toDouble(),
      ),
      builder: (context, animated, child) => SizedBox.square(
        dimension: 138,
        child: CustomPaint(
          painter: _ScoreGaugePainter(
            progress: animated / 100,
            track: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.68),
            start: Theme.of(context).colorScheme.primary,
            end: Theme.of(context).colorScheme.secondary,
          ),
          child: Center(
            child: Text(
              score == null ? '—' : animated.round().toString(),
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  const _ScoreGaugePainter({
    required this.progress,
    required this.track,
    required this.start,
    required this.end,
  });

  final double progress;
  final Color track;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2832, false, trackPaint);
    if (progress <= 0) return;
    final scorePaint = Paint()
      ..shader = SweepGradient(colors: [start, end, start]).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * progress.clamp(0, 1),
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreGaugePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      track != oldDelegate.track ||
      start != oldDelegate.start ||
      end != oldDelegate.end;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.dashboard});

  final OverallProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _StatTile(
              width: width,
              icon: Icons.forum_rounded,
              value: '${dashboard.conversations.length}',
              label: 'Saved conversations',
            ),
            _StatTile(
              width: width,
              icon: Icons.fact_check_rounded,
              value: '${dashboard.recordedConversationCount}',
              label: 'Outcomes recorded',
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
  });

  final double width;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        semanticLabel: '$label: $value',
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppRadii.card,
              ),
              child: SizedBox.square(
                dimension: AppSizes.minimumTouchTarget,
                child: Icon(icon),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPerformanceCard extends StatelessWidget {
  const _ReplyPerformanceCard({required this.dashboard});

  final OverallProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final rate = dashboard.replyRate;
    return AppCard(
      semanticLabel: rate == null
          ? 'Reply performance. No completed reply outcomes recorded.'
          : 'Reply performance. $rate percent across ${dashboard.replySampleSize} completed outcomes. User reported.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_chat_read_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Reply performance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  rate == null ? '—' : '$rate%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AnimatedMetricBar(value: (rate ?? 0) / 100),
            const SizedBox(height: AppSpacing.sm),
            Text(
              rate == null
                  ? 'Record whether a reply arrived to begin.'
                  : 'Based on ${dashboard.replySampleSize} completed user-reported outcomes. Waiting results are excluded.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMetricBar extends StatelessWidget {
  const _AnimatedMetricBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MotionScope.reduceMotionOf(context);
    return TweenAnimationBuilder<double>(
      key: const Key('reply-performance-animation'),
      duration: reduceMotion
          ? Duration.zero
          : AppMotion.duration(context, AppMotionSpeed.normal),
      curve: AppMotion.standardCurve,
      tween: Tween(begin: reduceMotion ? value : 0, end: value),
      builder: (context, animated, child) => ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.pill)),
        child: LinearProgressIndicator(
          minHeight: 12,
          value: animated,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard({required this.dashboard});

  final OverallProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: 'Plan confirmation status. ${dashboard.planSummary}.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondaryContainer,
                  Theme.of(context).colorScheme.tertiaryContainer,
                ],
              ),
              borderRadius: AppRadii.card,
            ),
            child: const SizedBox.square(
              dimension: 52,
              child: Icon(Icons.event_available_rounded),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan confirmation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  dashboard.planSummary,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Confirmed means you recorded a clear agreement—not that the app predicted a date.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.reflection, required this.onTap});

  final String reflection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('private-reflection-card'),
      onTap: onTap,
      semanticLabel: reflection.isEmpty
          ? 'Private reflection. Add a note.'
          : 'Private reflection saved. Double tap to edit.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private reflection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  reflection.isEmpty
                      ? 'Capture what felt authentic, clear or worth changing next time.'
                      : reflection,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  reflection.isEmpty ? 'Add reflection' : 'Edit reflection',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _OutcomeSheet extends StatefulWidget {
  const _OutcomeSheet({required this.dashboard});

  final OverallProgressDashboard dashboard;

  @override
  State<_OutcomeSheet> createState() => _OutcomeSheetState();
}

class _OutcomeSheetState extends State<_OutcomeSheet> {
  late String _conversationId = widget.dashboard.conversations.first.id;
  ReplyOutcome _reply = ReplyOutcome.waiting;
  PlanConfirmation _plan = PlanConfirmation.notDiscussed;
  int _authenticity = 3;
  int _clarity = 3;
  int _boundaries = 3;

  @override
  void initState() {
    super.initState();
    _applyExisting(_conversationId);
  }

  void _applyExisting(String conversationId) {
    final existing = widget.dashboard.journal.outcomes
        .where((item) => item.conversationId == conversationId)
        .firstOrNull;
    setState(() {
      _conversationId = conversationId;
      _reply = existing?.replyOutcome ?? ReplyOutcome.waiting;
      _plan = existing?.planConfirmation ?? PlanConfirmation.notDiscussed;
      _authenticity = existing?.authenticityRating ?? 3;
      _clarity = existing?.clarityRating ?? 3;
      _boundaries = existing?.boundaryRating ?? 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: ListView(
        key: const Key('outcome-sheet'),
        shrinkWrap: true,
        children: [
          Text(
            'Update your outcomes',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your answers update only the overall dashboard. No conversation receives a score.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            key: const Key('outcome-conversation-picker'),
            initialValue: _conversationId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conversation'),
            items: [
              for (final conversation in widget.dashboard.conversations)
                DropdownMenuItem(
                  value: conversation.id,
                  child: Text(
                    _conversationLabel(conversation),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) _applyExisting(value);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChoiceSection<ReplyOutcome>(
            title: 'What happened after your reply?',
            values: ReplyOutcome.values,
            selected: _reply,
            labelFor: (value) => value.label,
            onSelected: (value) => setState(() => _reply = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ChoiceSection<PlanConfirmation>(
            title: 'Was a plan clearly agreed?',
            values: PlanConfirmation.values,
            selected: _plan,
            labelFor: (value) => value.label,
            onSelected: (value) => setState(() => _plan = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'How did your message feel?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _RatingControl(
            label: 'Sounded like me',
            value: _authenticity,
            onChanged: (value) => setState(() => _authenticity = value),
          ),
          _RatingControl(
            label: 'Expressed my point clearly',
            value: _clarity,
            onChanged: (value) => setState(() => _clarity = value),
          ),
          _RatingControl(
            label: 'Respected my boundaries',
            value: _boundaries,
            onChanged: (value) => setState(() => _boundaries = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const Key('save-outcome-action'),
            label: 'Update overall stats',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.pop(
              context,
              ConversationOutcome(
                conversationId: _conversationId,
                replyOutcome: _reply,
                planConfirmation: _plan,
                authenticityRating: _authenticity,
                clarityRating: _clarity,
                boundaryRating: _boundaries,
                updatedAt: DateTime.now().toUtc(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _conversationLabel(ConversationSummary conversation) {
    if (conversation.participantName.trim().isEmpty) return conversation.title;
    return '${conversation.title} • ${conversation.participantName}';
  }
}

class _ChoiceSection<T> extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(labelFor(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _RatingControl extends StatelessWidget {
  const _RatingControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. Rating $value out of 5.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text(label)),
              Text('$value / 5'),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$value',
            onChanged: (next) => onChanged(next.round()),
          ),
        ],
      ),
    );
  }
}
