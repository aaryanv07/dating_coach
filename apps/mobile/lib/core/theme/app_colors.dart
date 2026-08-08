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
    required this.gradientStart,
    required this.gradientEnd,
    required this.gradientAccent,
    required this.glow,
    required this.glassBackground,
    required this.glassBorder,
  });

  // ── Palette constants ────────────────────────────────────────────────────
  /// Hot pink — primary brand colour.
  static const Color hotPink = Color(0xFFFF2D78);

  /// Electric purple — secondary brand colour.
  static const Color electricPurple = Color(0xFF8B5CF6);

  /// Neon cyan — accent colour for highlights.
  static const Color neonCyan = Color(0xFF00D4FF);

  /// Deep violet — dark-mode background root.
  static const Color deepViolet = Color(0xFF0D0A1A);

  /// Midnight surface — slightly lighter than the background.
  static const Color midnightSurface = Color(0xFF16102A);

  /// Raised surface in dark mode.
  static const Color raisedSurface = Color(0xFF1E1535);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [hotPink, electricPurple],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D0A1A), Color(0xFF1A1030)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricPurple, neonCyan],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1535), Color(0xFF150F28)],
  );

  // ── Theme extensions ─────────────────────────────────────────────────────
  static const AppColors light = AppColors(
    surfaceRaised: Color(0xFFF3EEFF),
    textMuted: Color(0xFF7B6F90),
    border: Color(0xFFE0D8F5),
    success: Color(0xFF22C55E),
    caution: Color(0xFFF59E0B),
    risk: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    focus: hotPink,
    gradientStart: hotPink,
    gradientEnd: electricPurple,
    gradientAccent: neonCyan,
    glow: Color(0x40FF2D78),
    glassBackground: Color(0x1AFF2D78),
    glassBorder: Color(0x40D1A8FF),
  );

  static const AppColors dark = AppColors(
    surfaceRaised: raisedSurface,
    textMuted: Color(0xFF9D8FBF),
    border: Color(0xFF2D2050),
    success: Color(0xFF4ADE80),
    caution: Color(0xFFFBBF24),
    risk: Color(0xFFF87171),
    info: neonCyan,
    focus: hotPink,
    gradientStart: hotPink,
    gradientEnd: electricPurple,
    gradientAccent: neonCyan,
    glow: Color(0x60FF2D78),
    glassBackground: Color(0x1A8B5CF6),
    glassBorder: Color(0x508B5CF6),
  );

  final Color surfaceRaised;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color caution;
  final Color risk;
  final Color info;
  final Color focus;
  final Color gradientStart;
  final Color gradientEnd;
  final Color gradientAccent;
  final Color glow;
  final Color glassBackground;
  final Color glassBorder;

  LinearGradient get primaryGradientInstance =>
      LinearGradient(colors: [gradientStart, gradientEnd]);

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
    Color? gradientStart,
    Color? gradientEnd,
    Color? gradientAccent,
    Color? glow,
    Color? glassBackground,
    Color? glassBorder,
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
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientAccent: gradientAccent ?? this.gradientAccent,
      glow: glow ?? this.glow,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
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
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      gradientAccent: Color.lerp(gradientAccent, other.gradientAccent, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
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
