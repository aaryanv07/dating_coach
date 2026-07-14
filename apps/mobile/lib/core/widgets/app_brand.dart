import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
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
          child: Text(
            AppConfig.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

class _ConvoMarkPainter extends CustomPainter {
  const _ConvoMarkPainter({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final primaryPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final secondaryPaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.fill;

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

    canvas.drawCircle(
      Offset(size.width * 0.36, size.height * 0.43),
      size.width * 0.055,
      secondaryPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.56, size.height * 0.43),
      size.width * 0.055,
      secondaryPaint,
    );
  }

  @override
  bool shouldRepaint(_ConvoMarkPainter oldDelegate) {
    return primary != oldDelegate.primary || secondary != oldDelegate.secondary;
  }
}
