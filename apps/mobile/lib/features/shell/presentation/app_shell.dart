import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppTabTransition(
        index: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: _ConvoNavigationDock(
        key: const Key('simplified-bottom-navigation'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _selectDestination(context, index),
      ),
    );
  }
}

class _ConvoNavigationDock extends StatelessWidget {
  const _ConvoNavigationDock({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.forum_outlined, Icons.forum_rounded, 'Chats'),
    (Icons.insights_outlined, Icons.insights_rounded, 'Stats'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Material(
      color: const Color(0xFF030C11),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: largeText ? 92 : 76,
          child: Row(
            children: [
              for (var index = 0; index < _destinations.length; index++)
                Expanded(
                  child: _DockDestination(
                    index: index,
                    destination: _destinations[index],
                    selected: index == selectedIndex,
                    compactLabel: largeText,
                    onTap: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
    required this.index,
    required this.destination,
    required this.selected,
    required this.compactLabel,
    required this.onTap,
  });

  final int index;
  final (IconData, IconData, String) destination;
  final bool selected;
  final bool compactLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = destination.$3;
    final visibleLabel = compactLabel && label == 'Settings' ? 'More' : label;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label tab',
      child: InkWell(
        key: ValueKey('navigation-${label.toLowerCase()}'),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            key: ValueKey('navigation-selection-$index'),
            duration: AppMotion.duration(context, AppMotionSpeed.fast),
            curve: AppMotion.standardCurve,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minimumTouchTarget,
              minHeight: AppSizes.minimumTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            margin: EdgeInsets.symmetric(
              horizontal: compactLabel ? AppSpacing.xs : AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => selected
                      ? LinearGradient(
                          colors: [scheme.secondary, scheme.primary],
                        ).createShader(bounds)
                      : const LinearGradient(
                          colors: [Color(0xFF9AB2B9), Color(0xFF9AB2B9)],
                        ).createShader(bounds),
                  child: Icon(
                    selected ? destination.$2 : destination.$1,
                    size: AppSizes.iconMedium,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  visibleLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : const Color(0xFF9AB2B9),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
