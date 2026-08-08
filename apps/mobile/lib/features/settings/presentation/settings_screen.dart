import 'dart:async';

import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:convo_coach/core/widgets/app_overlays.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final motionPreference = ref.watch(motionPreferenceProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: AppBackground(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              AppReveal(
                child: GradientText(
                  'You',
                  gradient: LinearGradient(
                    colors: [colors.gradientStart, colors.gradientEnd],
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppReveal(
                delay: const Duration(milliseconds: 60),
                child: AppCard(
                  highlight: true,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: const Text('Communication profile'),
                    subtitle: const Text(
                      'Tone, intention and message preferences',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => context.push('/settings/profile'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppReveal(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppReveal(
                delay: const Duration(milliseconds: 160),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
              ),
              const SizedBox(height: AppSpacing.xl),
              AppReveal(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'Comfort',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppReveal(
                delay: const Duration(milliseconds: 240),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Reduce motion'),
                        subtitle: const Text(
                          'Removes non-essential transitions',
                        ),
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
                        subtitle: const Text(
                          'Light confirmation for key actions',
                        ),
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
              ),
              const SizedBox(height: AppSpacing.xl),
              AppReveal(
                delay: const Duration(milliseconds: 280),
                child: Text(
                  'Privacy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppReveal(
                delay: const Duration(milliseconds: 320),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Privacy promise'),
                    subtitle: const Text(
                      'Control, consent and minimal retention',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () {
                      unawaited(
                        showAppDialog(
                          context: context,
                          title: 'Your control comes first',
                          message:
                              'This build uses mock data and does not import or store conversations.',
                          primaryLabel: 'Done',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
