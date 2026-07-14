import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme build({required Color text, required Color textMuted}) {
    return TextTheme(
      displaySmall: TextStyle(
        color: text,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: text,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: text,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0,
      ),
    );
  }
}
