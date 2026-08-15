import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes expose vibrant semantic roles', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFFAF7FF));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF0D0A1A));
    expect(light.extension<AppColors>()?.success, const Color(0xFF22C55E));
    expect(dark.extension<AppColors>()?.risk, const Color(0xFFF87171));
    expect(light.extension<AppColors>()?.gradientStart, AppColors.hotPink);
    expect(dark.extension<AppColors>()?.gradientEnd, AppColors.electricPurple);
    expect(light.textTheme.bodyLarge?.letterSpacing, 0);
    expect(dark.textTheme.headlineMedium?.letterSpacing, -0.5);
  });

  test('theme and reduced motion preferences are explicit state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    expect(container.read(themeModeProvider), ThemeMode.light);

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
