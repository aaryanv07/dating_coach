import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surfaceRaised,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.caution,
    required this.risk,
    required this.info,
    required this.focus,
  });

  static const AppColors light = AppColors(
    surfaceRaised: Color(0xFFFFFFFF),
    textMuted: Color(0xFF5D636F),
    border: Color(0xFFD7DAE0),
    success: Color(0xFF25743A),
    caution: Color(0xFF8A5400),
    risk: Color(0xFFB3261E),
    info: Color(0xFF006B8F),
    focus: Color(0xFF006B8F),
  );

  static const AppColors dark = AppColors(
    surfaceRaised: Color(0xFF272B30),
    textMuted: Color(0xFFB5BAC3),
    border: Color(0xFF444950),
    success: Color(0xFF77D38B),
    caution: Color(0xFFF0B45A),
    risk: Color(0xFFFFB4AB),
    info: Color(0xFF78D1F0),
    focus: Color(0xFF78D1F0),
  );

  final Color surfaceRaised;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color caution;
  final Color risk;
  final Color info;
  final Color focus;

  @override
  AppColors copyWith({
    Color? surfaceRaised,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? caution,
    Color? risk,
    Color? info,
    Color? focus,
  }) {
    return AppColors(
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      success: success ?? this.success,
      caution: caution ?? this.caution,
      risk: risk ?? this.risk,
      info: info ?? this.info,
      focus: focus ?? this.focus,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      risk: Color.lerp(risk, other.risk, t)!,
      info: Color.lerp(info, other.info, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

extension AppColorContext on BuildContext {
  AppColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light);
  }
}
