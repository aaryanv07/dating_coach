import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MotionPreference { system, reduced }

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) => state = mode;
}

class MotionPreferenceController extends Notifier<MotionPreference> {
  @override
  MotionPreference build() => MotionPreference.system;

  void setReduced({required bool reduced}) {
    state = reduced ? MotionPreference.reduced : MotionPreference.system;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final motionPreferenceProvider =
    NotifierProvider<MotionPreferenceController, MotionPreference>(
      MotionPreferenceController.new,
    );
