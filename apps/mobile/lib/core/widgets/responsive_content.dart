import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
    this.includeTopSafeArea = false,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final bool includeTopSafeArea;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: includeTopSafeArea,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 380
              ? AppSpacing.lg
              : AppSpacing.xl;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
