import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() {
    return _build(
      brightness: Brightness.light,
      background: const Color(0xFFF2FBFB),
      surface: const Color(0xFFFFFFFF),
      text: const Color(0xFF092C36),
      primary: const Color(0xFF5740C8),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFE4DFFF),
      secondary: const Color(0xFFB83273),
      secondaryContainer: const Color(0xFFFFDDEA),
      tertiary: const Color(0xFF006E75),
      tertiaryContainer: const Color(0xFFC5F4EF),
      appColors: AppColors.light,
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      background: const Color(0xFF03171D),
      surface: const Color(0xFF08242C),
      text: const Color(0xFFF2FCFC),
      primary: const Color(0xFFC2B5FF),
      onPrimary: const Color(0xFF24125F),
      primaryContainer: const Color(0xFF382D72),
      secondary: const Color(0xFFFF90BE),
      secondaryContainer: const Color(0xFF642644),
      tertiary: const Color(0xFF69E3D8),
      tertiaryContainer: const Color(0xFF0B4B50),
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
    required Color primaryContainer,
    required Color secondary,
    required Color secondaryContainer,
    required Color tertiary,
    required Color tertiaryContainer,
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
          primaryContainer: primaryContainer,
          secondary: secondary,
          secondaryContainer: secondaryContainer,
          tertiary: tertiary,
          tertiaryContainer: tertiaryContainer,
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
        backgroundColor: background,
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
          borderRadius: AppRadii.hero,
          side: BorderSide(color: appColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
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
        backgroundColor: brightness == Brightness.light
            ? text
            : const Color(0xFF020F14),
        indicatorColor: primary.withValues(alpha: 0.32),
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFA9C5CA),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFA9C5CA),
            fontWeight: FontWeight.w800,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.hero),
      ),
      dividerTheme: DividerThemeData(color: appColors.border, thickness: 1),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: appColors.border, width: 1.4),
          backgroundColor: surface.withValues(alpha: 0.82),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
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
