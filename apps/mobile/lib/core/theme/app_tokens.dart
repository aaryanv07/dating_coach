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
  static const double small = 10;
  static const double medium = 20;
  static const double large = 28;
  static const double pill = 100;
  static const BorderRadius card = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius button = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(large));
}

abstract final class AppSizes {
  static const double minimumTouchTarget = 44;
  static const double buttonHeight = 56;
  static const double iconSmall = 18;
  static const double iconMedium = 24;
  static const double maxContentWidth = 640;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration deliberate = Duration(milliseconds: 420);
  static const Duration loadingPulse = Duration(milliseconds: 900);
  static const Duration ambient = Duration(milliseconds: 2400);
}

abstract final class AppOpacity {
  static const double muted = 0.72;
  static const double disabled = 0.42;
  static const double pressed = 0.88;
}
