import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_coach/application/conversation_coach_controller.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationCoachScreen extends ConsumerWidget {
  const ConversationCoachScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationCoachProvider(conversationId));
    final controller = ref.read(
      conversationCoachProvider(conversationId).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation Coach')),
      body: switch (state) {
        ConversationCoachLoading() => _Loading(onCancel: controller.cancel),
        ConversationCoachGrantingConsent() => const _GrantingConsent(),
        ConversationCoachReady(:final preview) => _Preview(
          preview: preview,
          onReport: controller.reportOutput,
        ),
        ConversationCoachFeatureDisabled() => const _SafeState(
          icon: Icons.lock_outline_rounded,
          title: 'Preview is disabled',
          message:
              'The server-side Conversation Coach feature is off. No conversation data was processed.',
        ),
        ConversationCoachMockDisabled() => const _SafeState(
          icon: Icons.science_outlined,
          title: 'Mock execution is disabled',
          message:
              'The deterministic mock must be explicitly enabled before this preview can run.',
        ),
        ConversationCoachEmpty() => const AppEmptyState(
          title: 'No preview sections',
          message:
              'The server returned no structural placeholder sections. No coaching was generated.',
        ),
        ConversationCoachReviewIncomplete() => const _SafeState(
          icon: Icons.fact_check_outlined,
          title: 'Review is incomplete',
          message:
              'Confirm every item in the canonical conversation timeline before using this preview.',
        ),
        ConversationCoachUnsupported() => const _SafeState(
          icon: Icons.data_object_rounded,
          title: 'Conversation version unsupported',
          message:
              'This app cannot safely render the returned schema or timeline version.',
        ),
        ConversationCoachConsentRequired() => const _SafeState(
          icon: Icons.privacy_tip_outlined,
          title: 'Consent is required',
          message:
              'Active conversation-history consent is required before the server can process reviewed data.',
        ),
        ConversationCoachExternalConsentRequired() =>
          _ExternalProcessingConsent(
            onConsent: controller.grantExternalProcessingConsent,
          ),
        ConversationCoachTimedOut() => _RetryState(
          title: 'Preview timed out',
          message: 'The request stopped safely before a preview was available.',
          onRetry: controller.load,
        ),
        ConversationCoachCancelled() => _RetryState(
          title: 'Preview cancelled',
          message: 'Processing was cancelled. No coach output was stored.',
          onRetry: controller.load,
        ),
        ConversationCoachExecutionFailed() => _RetryState(
          title: 'Preview execution failed',
          message:
              'The mock pipeline stopped safely. No provider payload or coaching content is shown.',
          onRetry: controller.load,
        ),
        ConversationCoachAllowanceExhausted() => const _SafeState(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Monthly coaching allowance used',
          message:
              'You can still view saved conversations, safety guidance, and privacy controls. Live purchases are not enabled in this build.',
        ),
        ConversationCoachRateLimited() => _RetryState(
          title: 'Please wait a moment',
          message:
              'The server safely limited repeated requests. Your allowance was not consumed for a failed attempt.',
          onRetry: controller.load,
        ),
        ConversationCoachBudgetUnavailable() => const _SafeState(
          icon: Icons.shield_outlined,
          title: 'Coaching temporarily unavailable',
          message:
              'The server-side cost guardrail stopped this request. Your conversation remains available and the failed request did not consume an allowance.',
        ),
        ConversationCoachNetworkUnavailable() => AppOfflineState(
          actionLabel: 'Try again',
          onAction: controller.load,
        ),
        ConversationCoachUnavailable() => const _SafeState(
          icon: Icons.lock_outline_rounded,
          title: 'Preview unavailable',
          message:
              'This non-production preview is not enabled for the current app configuration or conversation.',
        ),
        ConversationCoachSafeFailure() => _RetryState(
          title: 'Preview unavailable',
          message:
              'The request failed safely without exposing private diagnostics.',
          onRetry: controller.load,
        ),
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        key: const Key('coach-preview-loading'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const AppSkeleton(height: 112),
          const SizedBox(height: AppSpacing.md),
          const AppSkeleton(height: 180),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Cancel preview',
            icon: Icons.close_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _GrantingConsent extends StatelessWidget {
  const _GrantingConsent();

  @override
  Widget build(BuildContext context) {
    return const AppStateView(
      icon: Icons.privacy_tip_outlined,
      title: 'Recording your choice',
      message: 'No conversation content is sent until consent is recorded.',
    );
  }
}

class _ExternalProcessingConsent extends StatelessWidget {
  const _ExternalProcessingConsent({required this.onConsent});

  final VoidCallback onConsent;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 680,
      child: ListView(
        key: const Key('external-ai-consent'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Before external AI coaching',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: Text(
              'If you continue, the server will send only the reviewed message text, speaker labels, and opaque event IDs needed for this request through OpenRouter to the model provider selected for your plan. Free coaching uses GPT-4o mini and Plus coaching uses GPT-5.6 Terra. Screenshot bytes, contact names, source paths, OCR metadata, and your ConvoCoach account ID are not sent. ConvoCoach requests zero-data-retention routing, denies provider data collection, and does not save the generated result. OpenRouter and the selected provider process the request under their applicable terms.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'AI interpretations can be wrong. They are possibilities, not facts about another person. Review and edit every draft before deciding whether to send it.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'I consent and want coaching',
            icon: Icons.check_rounded,
            onPressed: onConsent,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This external-processing consent is separate from consent to save conversation history.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.preview, required this.onReport});

  final ConversationCoachPreviewViewModel preview;
  final Future<bool> Function(
    String responseId,
    CoachOutputReportCategory category,
  )
  onReport;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 760,
      child: AppDepthReveal(
        key: const Key('coach-result-depth-reveal'),
        child: ListView(
          key: const Key('coach-preview-ready'),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                preview.mockExecution
                    ? 'Mock infrastructure preview'
                    : 'AI conversation coaching',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              preview.mockExecution
                  ? 'This validates the private data path and renderer structure. It contains no genuine coaching, advice, analysis, recommendations, or message drafts.'
                  : 'Generated by ${preview.providerLabel}. AI interpretations are uncertain. Review every suggestion and choose what, if anything, you want to send.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!preview.mockExecution &&
                preview.allowanceRemaining != null &&
                preview.allowanceLimit != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                semanticLabel: 'Conversation analysis allowance',
                child: Text(
                  '${preview.allowanceRemaining} of ${preview.allowanceLimit} conversation analyses remain on the ${preview.planCode ?? 'current'} plan.',
                ),
              ),
            ],
            for (final notice in preview.notices) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                semanticLabel: notice,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: context.appColors.info,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(notice)),
                  ],
                ),
              ),
            ],
            for (final section in preview.sections) ...[
              const SizedBox(height: AppSpacing.lg),
              _PreviewSection(section: section),
            ],
            if (!preview.mockExecution) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('report-ai-output'),
                label: 'Report this AI response',
                icon: Icons.flag_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _showReportSheet(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Reports help us improve safety. Your chat and the generated text are not included.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.lg),
              _DeveloperEvidence(preview: preview),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showReportSheet(BuildContext context) async {
    final category = await showModalBottomSheet<CoachOutputReportCategory>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const Key('report-ai-output-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text(
              'What should we review?',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Only an opaque response ID and the category are sent. Conversation text, screenshots, and the generated response are not included.',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in CoachOutputReportCategory.values)
              ListTile(
                minTileHeight: 48,
                leading: const Icon(Icons.flag_outlined),
                title: Text(item.label),
                onTap: () => Navigator.of(sheetContext).pop(item),
              ),
          ],
        ),
      ),
    );
    if (category == null || !context.mounted) return;
    final received = await onReport(preview.responseId, category);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          received
              ? 'Report received. Thank you for helping improve safety.'
              : 'The report could not be sent. Please try again.',
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.section});

  final ConversationCoachSectionViewModel section;

  @override
  Widget build(BuildContext context) {
    final icon = switch (section.status) {
      ConversationCoachSectionStatus.available =>
        Icons.check_circle_outline_rounded,
      ConversationCoachSectionStatus.unavailable =>
        Icons.not_interested_outlined,
      ConversationCoachSectionStatus.notice => Icons.info_outline_rounded,
    };
    return Semantics(
      container: true,
      label: section.semanticLabel,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(icon, size: AppSizes.iconSmall),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      section.heading,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            if (section.items.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Text('No structural items are available.'),
            ],
            for (final item in section.items) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ],
            if (section.evidenceReferenceCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${section.evidenceReferenceCount} content-free structural evidence references',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeveloperEvidence extends StatelessWidget {
  const _DeveloperEvidence({required this.preview});

  final ConversationCoachPreviewViewModel preview;

  @override
  Widget build(BuildContext context) {
    final versionLines = <String>[
      'Provider: ${preview.providerLabel}',
      if (preview.analyticsSchemaVersion != null)
        'Analytics schema: ${preview.analyticsSchemaVersion}',
      if (preview.analyticsCalculationVersion != null)
        'Calculation: ${preview.analyticsCalculationVersion}',
      if (preview.sourceEventSchemaVersion != null)
        'Event schema: ${preview.sourceEventSchemaVersion}',
      if (preview.inputTokens != null) 'Input tokens: ${preview.inputTokens}',
      if (preview.outputTokens != null)
        'Output tokens: ${preview.outputTokens}',
      if (preview.planCode != null) 'Plan: ${preview.planCode}',
      if (preview.allowanceRemaining != null)
        'Analysis allowance remaining: ${preview.allowanceRemaining}',
      if (preview.allowanceResetAt != null)
        'Allowance resets: ${preview.allowanceResetAt!.toIso8601String()}',
      'Response: ${preview.responseId}',
      'Correlation: ${preview.correlationId}',
    ];
    return AppCard(
      child: ExpansionTile(
        title: const Text('Developer evidence'),
        subtitle: const Text('Content-free schema and correlation identifiers'),
        children: [
          SelectableText(
            versionLines.join('\n'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SafeState extends StatelessWidget {
  const _SafeState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppStateView(icon: icon, title: title, message: message);
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: title,
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
