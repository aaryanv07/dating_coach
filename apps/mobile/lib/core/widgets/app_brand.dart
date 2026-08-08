import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Brand mark drawn with the vibrant pink→purple gradient plus a glow.
class ConvoMark extends StatelessWidget {
  const ConvoMark({this.size = 40, this.glow = false, super.key});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _ConvoMarkPainter(
        gradientStart: colors.gradientStart,
        gradientEnd: colors.gradientEnd,
        accent: colors.gradientAccent,
      ),
    );

    return Semantics(
      image: true,
      label: '${AppConfig.name} logo',
      child: ExcludeSemantics(
        child: glow
            ? DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.glow,
                      blurRadius: size * 0.6,
                      spreadRadius: size * 0.05,
                    ),
                  ],
                ),
                child: mark,
              )
            : mark,
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = compact
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleLarge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConvoMark(size: compact ? 30 : 40),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: GradientText(
            AppConfig.name,
            gradient: LinearGradient(
              colors: [colors.gradientStart, colors.gradientEnd],
            ),
            style: style?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ConvoMarkPainter extends CustomPainter {
  const _ConvoMarkPainter({
    required this.gradientStart,
    required this.gradientEnd,
    required this.accent,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset.zero & size;
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()..color = accent;

    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.14,
        size.width * 0.72,
        size.height * 0.58,
      ),
      Radius.circular(size.width * 0.24),
    );
    canvas.drawRRect(bubble, gradientPaint);

    final tail = Path()
      ..moveTo(size.width * 0.56, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.88,
        size.width * 0.34,
        size.height * 0.85,
      );
    canvas.drawPath(tail, gradientPaint);

    canvas.drawCircle(
      Offset(size.width * 0.36, size.height * 0.43),
      size.width * 0.055,
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.56, size.height * 0.43),
      size.width * 0.055,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(_ConvoMarkPainter oldDelegate) {
    return gradientStart != oldDelegate.gradientStart ||
        gradientEnd != oldDelegate.gradientEnd ||
        accent != oldDelegate.accent;
  }
}
