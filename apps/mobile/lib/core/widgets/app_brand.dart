import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:flutter/material.dart';

class ConvoMark extends StatelessWidget {
  const ConvoMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: '${AppConfig.name} logo',
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _ConvoMarkPainter(
            primary: scheme.primary,
            secondary: scheme.secondary,
            accent: scheme.tertiary,
          ),
        ),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConvoMark(size: compact ? 30 : 40),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: AppGradientText(
            AppConfig.name,
            maxLines: 1,
            style: compact
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  )
                : Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
          ),
        ),
      ],
    );
  }
}

class _ConvoMarkPainter extends CustomPainter {
  const _ConvoMarkPainter({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final primaryPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.74
      ..strokeCap = StrokeCap.round;

    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.14,
        size.width * 0.72,
        size.height * 0.58,
      ),
      Radius.circular(size.width * 0.2),
    );
    canvas.drawRRect(bubble, primaryPaint);

    final tail = Path()
      ..moveTo(size.width * 0.56, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.88,
        size.width * 0.34,
        size.height * 0.85,
      );
    canvas.drawPath(tail, primaryPaint);

    final upperWave = Path()
      ..moveTo(size.width * 0.28, size.height * 0.42)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.33,
        size.width * 0.46,
        size.height * 0.51,
        size.width * 0.57,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.36,
        size.width * 0.69,
        size.height * 0.4,
        size.width * 0.72,
        size.height * 0.43,
      );
    wavePaint.color = accent;
    canvas.drawPath(upperWave, wavePaint);

    final lowerWave = Path()
      ..moveTo(size.width * 0.3, size.height * 0.54)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.45,
        size.width * 0.5,
        size.height * 0.63,
        size.width * 0.61,
        size.height * 0.54,
      );
    wavePaint.color = secondary;
    canvas.drawPath(lowerWave, wavePaint);

    canvas.drawCircle(
      Offset(size.width * 0.57, size.height * 0.29),
      size.width * 0.052,
      Paint()..color = secondary,
    );
  }

  @override
  bool shouldRepaint(_ConvoMarkPainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        accent != oldDelegate.accent;
  }
}
