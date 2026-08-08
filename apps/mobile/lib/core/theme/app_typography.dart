import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme build({required Color text, required Color textMuted}) {
    return TextTheme(
      displaySmall: TextStyle(
        color: text,
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: text,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
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
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        color: textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.2,
      ),
    );
  }
}

/// Renders text filled with the brand gradient.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    required this.gradient,
    this.style,
    this.textAlign,
    super.key,
  });

  final String text;
  final Gradient gradient;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
