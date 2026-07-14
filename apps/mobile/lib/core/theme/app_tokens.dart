import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadii {
  static const double small = 4;
  static const double medium = 8;
  static const BorderRadius card = BorderRadius.all(Radius.circular(medium));
}

abstract final class AppSizes {
  static const double minimumTouchTarget = 44;
  static const double buttonHeight = 52;
  static const double iconSmall = 18;
  static const double iconMedium = 24;
  static const double maxContentWidth = 640;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration deliberate = Duration(milliseconds: 280);
  static const Duration loadingPulse = Duration(milliseconds: 900);
}

abstract final class AppOpacity {
  static const double muted = 0.72;
  static const double disabled = 0.42;
  static const double pressed = 0.88;
}
