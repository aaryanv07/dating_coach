import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes expose premium semantic roles', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF121416));
    expect(light.extension<AppColors>()?.success, const Color(0xFF25743A));
    expect(dark.extension<AppColors>()?.risk, const Color(0xFFFFB4AB));
    expect(light.textTheme.bodyLarge?.letterSpacing, 0);
    expect(dark.textTheme.headlineMedium?.letterSpacing, 0);
  });

  test('theme and reduced motion preferences are explicit state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    expect(container.read(motionPreferenceProvider), MotionPreference.system);
    container.read(motionPreferenceProvider.notifier).setReduced(reduced: true);
    expect(container.read(motionPreferenceProvider), MotionPreference.reduced);
  });

  test(
    'normal motion tokens stay inside the 150 to 300 millisecond budget',
    () {
      for (final duration in [
        AppDurations.fast,
        AppDurations.normal,
        AppDurations.deliberate,
      ]) {
        expect(duration.inMilliseconds, inInclusiveRange(150, 300));
      }
    },
  );
}
