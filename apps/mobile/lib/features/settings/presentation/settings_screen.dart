import 'dart:async';

import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/authentication/application/mock_auth_controller.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/progress/application/progress_dashboard_controller.dart';
import 'package:convo_coach/features/settings/application/account_actions.dart';
import 'package:convo_coach/features/settings/application/account_export_sharer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Protected outcome stats and your private reflection will be cleared from this device. Saved account conversations stay on the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await ref.read(accountActionsProvider).signOut();
    if (!context.mounted) return;
    if (!succeeded) {
      _showFailure(context, 'Sign out could not be completed.');
      return;
    }
    ref.read(mockAuthProvider.notifier).signOut();
    ref.invalidate(progressDashboardProvider);
    ref.invalidate(conversationListProvider);
    context.go('/auth');
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This requests deletion of your saved conversations, profile, consent records and account data. Protected outcome stats and your private reflection will also be removed from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-account-deletion'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await ref.read(accountActionsProvider).deleteAccount();
    if (!context.mounted) return;
    if (!succeeded) {
      _showFailure(
        context,
        'Account deletion could not be requested. Your local data was kept.',
      );
      return;
    }
    ref.read(mockAuthProvider.notifier).signOut();
    ref.invalidate(progressDashboardProvider);
    ref.invalidate(conversationListProvider);
    context.go('/auth');
  }

  Future<void> _exportAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export your data?'),
        content: const Text(
          'The export can contain your profile and saved conversation text. Choose a private destination in the system share sheet. ConvoCoach deletes its temporary export after sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-account-export'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final export = await ref.read(accountActionsProvider).exportAccount();
    if (!context.mounted) return;
    if (export == null) {
      _showFailure(context, 'Your data export could not be prepared.');
      return;
    }
    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      await ref
          .read(accountExportSharerProvider)
          .share(export, sharePositionOrigin: shareOrigin);
    } on Object {
      if (context.mounted) {
        _showFailure(context, 'The system share sheet could not be opened.');
      }
    }
  }

  void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final motionPreference = ref.watch(motionPreferenceProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Text('You', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Your profile'),
                subtitle: const Text(
                  'Photo, name, job, likes and coaching preferences',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => context.push('/settings/profile'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Plan and usage'),
                subtitle: const Text('Preview Free and ConvoCoach Plus'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => context.push('/settings/subscription'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setMode(selection.first);
                        ref.read(hapticsProvider).selection();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Comfort', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Reduce motion'),
                    subtitle: const Text('Removes non-essential transitions'),
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    value: motionPreference == MotionPreference.reduced,
                    onChanged: (value) {
                      ref
                          .read(motionPreferenceProvider.notifier)
                          .setReduced(reduced: value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Haptic feedback'),
                    subtitle: const Text('Light confirmation for key actions'),
                    secondary: const Icon(Icons.vibration_rounded),
                    value: hapticsEnabled,
                    onChanged: (value) {
                      ref
                          .read(hapticsEnabledProvider.notifier)
                          .setEnabled(enabled: value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacy promise'),
                subtitle: const Text('Control, consent and minimal retention'),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () {
                  unawaited(
                    showAppDialog(
                      context: context,
                      title: 'Your control comes first',
                      message:
                          'Reviewed conversation content is processed only after your explicit action and consent. Screenshot bytes stay temporary, and external AI processing requires a separate disclosure and consent.',
                      primaryLabel: 'Done',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('sign-out-action'),
                    minTileHeight: AppSizes.minimumTouchTarget,
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign out'),
                    subtitle: const Text('Clear private data from this device'),
                    onTap: () => _signOut(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('export-account-action'),
                    minTileHeight: AppSizes.minimumTouchTarget,
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export my data'),
                    subtitle: const Text('Share a private JSON copy'),
                    onTap: () => _exportAccount(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('delete-account-action'),
                    minTileHeight: AppSizes.minimumTouchTarget,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: context.appColors.risk,
                    ),
                    title: Text(
                      'Delete account',
                      style: TextStyle(color: context.appColors.risk),
                    ),
                    subtitle: const Text('Permanently remove account data'),
                    onTap: () => _deleteAccount(context, ref),
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
