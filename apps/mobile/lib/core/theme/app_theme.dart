import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    return _build(
      brightness: Brightness.light,
      background: const Color(0xFFFAF7FF),
      surface: const Color(0xFFFFFFFF),
      text: const Color(0xFF1A1128),
      primary: AppColors.hotPink,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: AppColors.electricPurple,
      tertiary: AppColors.neonCyan,
      appColors: AppColors.light,
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      background: AppColors.deepViolet,
      surface: AppColors.midnightSurface,
      text: const Color(0xFFF5F2FF),
      primary: AppColors.hotPink,
      onPrimary: const Color(0xFFFFFFFF),
      secondary: AppColors.electricPurple,
      tertiary: AppColors.neonCyan,
      appColors: AppColors.dark,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color text,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color tertiary,
    required AppColors appColors,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          tertiary: tertiary,
          error: appColors.risk,
          outline: appColors.border,
          surface: surface,
          onSurface: text,
        );
    final textTheme = AppTypography.build(
      text: text,
      textMuted: appColors.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[appColors],
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: appColors.surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: appColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: appColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: appColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.card,
          borderSide: BorderSide(color: appColors.focus, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.22),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      dividerTheme: DividerThemeData(color: appColors.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
