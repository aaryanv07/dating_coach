import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes expose oceanic semantic roles', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFF2FBFB));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF03171D));
    expect(light.colorScheme.primary, const Color(0xFF5740C8));
    expect(light.colorScheme.secondary, const Color(0xFFB83273));
    expect(light.colorScheme.tertiary, const Color(0xFF006E75));
    expect(light.extension<AppColors>()?.success, const Color(0xFF087B57));
    expect(dark.extension<AppColors>()?.risk, const Color(0xFFFFB4AB));
    expect(light.textTheme.bodyLarge?.letterSpacing, 0);
    expect(dark.textTheme.headlineMedium?.letterSpacing, -0.7);
    expect(light.navigationBarTheme.height, 76);
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
