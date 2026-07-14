import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AppHaptics {
  void selection();
  void confirmation();
  void success();
  void warning();
}

class SystemAppHaptics implements AppHaptics {
  const SystemAppHaptics();

  @override
  void selection() => unawaited(HapticFeedback.selectionClick());

  @override
  void confirmation() => unawaited(HapticFeedback.lightImpact());

  @override
  void success() => unawaited(HapticFeedback.mediumImpact());

  @override
  void warning() => unawaited(HapticFeedback.heavyImpact());
}

class NoopAppHaptics implements AppHaptics {
  const NoopAppHaptics();

  @override
  void selection() {}

  @override
  void confirmation() {}

  @override
  void success() {}

  @override
  void warning() {}
}

class HapticsEnabledController extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled({required bool enabled}) => state = enabled;
}

final hapticsEnabledProvider = NotifierProvider<HapticsEnabledController, bool>(
  HapticsEnabledController.new,
);

final hapticsProvider = Provider<AppHaptics>((ref) {
  return ref.watch(hapticsEnabledProvider)
      ? const SystemAppHaptics()
      : const NoopAppHaptics();
});
