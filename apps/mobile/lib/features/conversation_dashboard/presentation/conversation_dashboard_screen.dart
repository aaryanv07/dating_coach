import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_dashboard/application/conversation_dashboard_controller.dart';
import 'package:convo_coach/features/conversation_dashboard/domain/dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationDashboardScreen extends ConsumerWidget {
  const ConversationDashboardScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationDashboardProvider(conversationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation data')),
      body: state.when(
        loading: () => const _DashboardLoadingState(),
        error: (error, stackTrace) => AppErrorState(
          title: 'Dashboard unavailable',
          message: 'The conversation data could not be loaded.',
          actionLabel: 'Try again',
          onAction: () =>
              ref.invalidate(conversationDashboardProvider(conversationId)),
        ),
        data: (dashboardState) => switch (dashboardState) {
          ConversationDashboardEmpty() => const AppEmptyState(
            title: 'No analytics available',
            message:
                'Confirm a reviewed conversation before opening its deterministic data dashboard.',
          ),
          ConversationDashboardUnsupported(:final message) => AppStateView(
            icon: Icons.data_object_rounded,
            title: 'Unsupported analytics data',
            message: message,
          ),
          ConversationDashboardReady(:final dashboard) => _DashboardContent(
            dashboard: dashboard,
          ),
        },
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        key: const Key('dashboard-loading-list'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: const [
          AppSkeleton(height: 108),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 180),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 220),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.dashboard});

  final ConversationDashboardViewModel dashboard;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        key: const Key('conversation-dashboard-list'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              'Observed conversation data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These are deterministic counts and intervals from the timeline you reviewed. They do not measure interest, compatibility, or relationship quality.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (dashboard.hasTimelineGaps) ...[
            const _TimelineGapNotice(),
            const SizedBox(height: AppSpacing.md),
          ],
          _QualityCard(quality: dashboard.quality),
          for (final section in dashboard.sections) ...[
            const SizedBox(height: AppSpacing.lg),
            _DashboardSection(section: section),
          ],
          const SizedBox(height: AppSpacing.lg),
          _DeveloperEvidence(
            sections: dashboard.sections,
            schemaVersion: dashboard.schemaVersion,
            calculationVersion: dashboard.calculationVersion,
          ),
        ],
      ),
    );
  }
}

class _TimelineGapNotice extends StatelessWidget {
  const _TimelineGapNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Timeline gap notice. This import contains one or more reviewed timeline gaps.',
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.timeline_rounded, color: context.appColors.caution),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timeline gaps are present',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Some timing or participation metrics may be unavailable. Each affected item explains why.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.quality});

  final DashboardQualityViewModel quality;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      semanticLabel: 'Data quality summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Data quality',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusPill(
                icon: Icons.check_circle_outline_rounded,
                label: '${quality.supportedMetricCount} supported',
              ),
              _StatusPill(
                icon: Icons.info_outline_rounded,
                label: '${quality.unsupportedMetricCount} unavailable',
              ),
              _StatusPill(
                icon: Icons.rule_rounded,
                label: 'Evidence: ${quality.confidenceLabel}',
              ),
            ],
          ),
          if (quality.missingDataLabels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Known limitations',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final reason in quality.missingDataLabels)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('• $reason'),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: context.appColors.border),
          borderRadius: AppRadii.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, size: AppSizes.iconSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.section});

  final DashboardSectionViewModel section;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              section.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            section.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < section.metrics.length; index++) ...[
            if (index > 0) const Divider(height: AppSpacing.xl),
            _MetricRow(metric: section.metrics[index]),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final DashboardMetricViewModel metric;

  @override
  Widget build(BuildContext context) {
    final statusLabel = metric.supported
        ? 'Evidence ${metric.confidenceLabel.toLowerCase()}'
        : metric.missingDataLabels.join(', ');
    return Semantics(
      key: Key('dashboard-metric-${metric.identifier}'),
      container: true,
      label: '${metric.label}: ${metric.valueLabel}. $statusLabel',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              metric.supported
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: AppSizes.iconSmall,
              color: metric.supported
                  ? context.appColors.success
                  : context.appColors.caution,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.label),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metric.supported
                        ? 'Evidence ${metric.confidenceLabel.toLowerCase()}'
                        : statusLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                metric.valueLabel,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperEvidence extends StatelessWidget {
  const _DeveloperEvidence({
    required this.sections,
    required this.schemaVersion,
    required this.calculationVersion,
  });

  final List<DashboardSectionViewModel> sections;
  final String schemaVersion;
  final String calculationVersion;

  @override
  Widget build(BuildContext context) {
    final metrics = [for (final section in sections) ...section.metrics];
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('developer-evidence-tile'),
        title: const Text('Developer evidence'),
        subtitle: const Text(
          'Content-free structural identifiers and version details',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              'Schema: $schemaVersion\nCalculation: $calculationVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final metric in metrics.where(
            (entry) => entry.evidence.isAvailable,
          )) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                '${metric.identifier}\n'
                'Events: ${metric.evidence.eventIds.join(', ')}\n'
                'Relationships: ${metric.evidence.relationshipIds.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: AppSpacing.xl),
          ],
          if (!metrics.any((entry) => entry.evidence.isAvailable))
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No structural evidence identifiers are available.'),
            ),
        ],
      ),
    );
  }
}
