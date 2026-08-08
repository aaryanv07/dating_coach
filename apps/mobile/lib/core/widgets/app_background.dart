import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Ambient vibrant background: a vertical brand gradient in dark mode with
/// soft glowing colour orbs, and a clean tinted wash in light mode.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, this.showOrbs = true, super.key});

  final Widget child;
  final bool showOrbs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.backgroundGradient
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFAF7FF),
                  Color.lerp(
                    const Color(0xFFFAF7FF),
                    colors.gradientEnd,
                    0.05,
                  )!,
                ],
              ),
      ),
      child: showOrbs
          ? Stack(
              children: [
                Positioned(
                  top: -80,
                  right: -60,
                  child: _GlowOrb(
                    color: colors.gradientEnd.withValues(
                      alpha: isDark ? 0.22 : 0.10,
                    ),
                    size: 240,
                  ),
                ),
                Positioned(
                  bottom: -100,
                  left: -80,
                  child: _GlowOrb(
                    color: colors.gradientStart.withValues(
                      alpha: isDark ? 0.16 : 0.08,
                    ),
                    size: 280,
                  ),
                ),
                child,
              ],
            )
          : child,
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
