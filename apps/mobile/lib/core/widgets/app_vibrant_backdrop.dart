import 'dart:math' as math;

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:flutter/material.dart';

class AppVibrantBackdrop extends StatelessWidget {
  const AppVibrantBackdrop({
    required this.child,
    this.animate = true,
    super.key,
  });

  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MotionScope.reduceMotionOf(context);
    return DecoratedBox(
      key: const Key('app-vibrant-backdrop'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.tertiaryContainer.withValues(alpha: 0.82),
            scheme.surface,
            scheme.primaryContainer.withValues(alpha: 0.58),
            scheme.secondaryContainer.withValues(alpha: 0.54),
          ],
          stops: const [0, 0.36, 0.7, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -116,
            right: -92,
            child: _PearlGlow(
              color: scheme.primaryContainer.withValues(alpha: 0.66),
              highlight: scheme.surface.withValues(alpha: 0.72),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -144,
            left: -122,
            child: _PearlGlow(
              color: scheme.tertiaryContainer.withValues(alpha: 0.62),
              highlight: scheme.secondaryContainer.withValues(alpha: 0.48),
              size: 310,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  key: const Key('mermaid-wave-reveal'),
                  duration: animate
                      ? AppMotion.duration(context, AppMotionSpeed.deliberate)
                      : Duration.zero,
                  curve: AppMotion.standardCurve,
                  tween: Tween<double>(
                    begin: animate && !reduceMotion ? 0 : 1,
                    end: 1,
                  ),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: CustomPaint(
                          key: const Key('mermaid-wave-field'),
                          painter: _MermaidWavePainter(
                            progress: value,
                            primary: scheme.primary,
                            secondary: scheme.secondary,
                            accent: scheme.tertiary,
                            pearl: scheme.surface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _PearlGlow extends StatelessWidget {
  const _PearlGlow({
    required this.color,
    required this.highlight,
    required this.size,
  });

  final Color color;
  final Color highlight;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.28, -0.32),
            colors: [highlight, color],
            stops: const [0, 0.72],
          ),
        ),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

class _MermaidWavePainter extends CustomPainter {
  const _MermaidWavePainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.pearl,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color pearl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    final baseY = size.height * (0.7 + (0.04 * (1 - progress)));
    final colors = [accent, primary, secondary];

    for (var index = 0; index < colors.length; index++) {
      final path = Path();
      final y = baseY + (index * 34);
      path.moveTo(-size.width * 0.12, y);
      path.cubicTo(
        size.width * 0.12,
        y - 52,
        size.width * 0.28,
        y + 44,
        size.width * 0.5,
        y,
      );
      path.cubicTo(
        size.width * 0.72,
        y - 44,
        size.width * 0.88,
        y + 52,
        size.width * 1.12,
        y,
      );
      wavePaint.color = colors[index].withValues(alpha: 0.1 + index * 0.025);
      canvas.drawPath(path, wavePaint);
    }

    final scalePaint = Paint()
      ..color = accent.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const radius = 28.0;
    for (double x = -radius; x < size.width + radius; x += radius * 1.72) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, size.height - 8), radius: radius),
        math.pi,
        math.pi,
        false,
        scalePaint,
      );
    }

    final pearlPaint = Paint()..color = pearl.withValues(alpha: 0.64);
    final pearlOutline = Paint()
      ..color = primary.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final pearlData in const [
      (Offset(0.13, 0.2), 5.0),
      (Offset(0.2, 0.13), 2.5),
      (Offset(0.87, 0.38), 3.5),
    ]) {
      final center = Offset(
        pearlData.$1.dx * size.width,
        pearlData.$1.dy * size.height,
      );
      canvas.drawCircle(center, pearlData.$2, pearlPaint);
      canvas.drawCircle(center, pearlData.$2, pearlOutline);
    }
  }

  @override
  bool shouldRepaint(_MermaidWavePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        accent != oldDelegate.accent ||
        pearl != oldDelegate.pearl;
  }
}
