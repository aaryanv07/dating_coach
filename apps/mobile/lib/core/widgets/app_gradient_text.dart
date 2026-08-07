import 'package:flutter/material.dart';

class AppGradientText extends StatelessWidget {
  const AppGradientText(
    this.text, {
    required this.style,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.tertiary, scheme.primary, scheme.secondary],
        stops: const [0, 0.54, 1],
      ).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
