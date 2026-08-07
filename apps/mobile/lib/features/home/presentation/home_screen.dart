import 'dart:async';

import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:convo_coach/core/widgets/responsive_content.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showQuickMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => _HomeQuickMenu(
        onSavedChats: () {
          Navigator.pop(sheetContext);
          context.go('/conversations');
        },
        onStats: () {
          Navigator.pop(sheetContext);
          context.go('/progress');
        },
        onSettings: () {
          Navigator.pop(sheetContext);
          context.go('/settings');
        },
      ),
    );
  }

  Future<void> _startImport(
    BuildContext context,
    WidgetRef ref,
    ConversationImportType type,
  ) async {
    await ref.read(conversationImportProvider.notifier).start(type);
    if (!context.mounted) return;
    context.push(
      type == ConversationImportType.screenshot
          ? '/import/screenshots'
          : '/import/paste',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: IconButton(
            key: const Key('home-menu-action'),
            tooltip: 'Open app menu',
            onPressed: () => _showQuickMenu(context),
            icon: const Icon(Icons.menu_rounded, size: 30),
          ),
        ),
        title: const BrandLockup(compact: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              key: const Key('home-new-chat-action'),
              tooltip: 'Upload a new chat',
              onPressed: () => unawaited(
                _startImport(context, ref, ConversationImportType.screenshot),
              ),
              icon: const Icon(Icons.add_rounded, size: 34),
            ),
          ),
        ],
      ),
      body: AppVibrantBackdrop(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xxxl,
            ),
            children: [
              AppReveal(
                child: AppGradientText(
                  'Upload a chat.\nKeep the reply yours.',
                  key: const Key('home-vibrant-headline'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 40,
                    height: 1.02,
                    letterSpacing: -1.45,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Review the conversation, explore respectful directions and choose what genuinely sounds like you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppReveal(
                offset: Offset(0, 8),
                child: _ConversationCoachPreview(),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SpotlightAction(
                child: AppButton(
                  key: const Key('home-upload-screenshots'),
                  label: 'Upload screenshots',
                  icon: Icons.add_photo_alternate_rounded,
                  semanticLabel: 'Upload conversation screenshots',
                  onPressed: () => unawaited(
                    _startImport(
                      context,
                      ref,
                      ConversationImportType.screenshot,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SecondaryActions(
                onPaste: () => unawaited(
                  _startImport(context, ref, ConversationImportType.paste),
                ),
                onSaved: () => context.go('/conversations'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  key: const Key('home-private-review-pill'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: AppSizes.iconSmall,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          AppConfig.mockMode
                              ? 'Private preview • stays on this device'
                              : 'You review and confirm before coaching',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQuickMenu extends StatelessWidget {
  const _HomeQuickMenu({
    required this.onSavedChats,
    required this.onStats,
    required this.onSettings,
  });

  final VoidCallback onSavedChats;
  final VoidCallback onStats;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('home-quick-menu'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your space', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            minTileHeight: AppSizes.minimumTouchTarget,
            leading: const Icon(Icons.forum_rounded),
            title: const Text('Saved chats'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSavedChats,
          ),
          ListTile(
            minTileHeight: AppSizes.minimumTouchTarget,
            leading: const Icon(Icons.insights_rounded),
            title: const Text('Overall stats'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onStats,
          ),
          ListTile(
            minTileHeight: AppSizes.minimumTouchTarget,
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _SpotlightAction extends StatelessWidget {
  const _SpotlightAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? const Color(0xFFF4FCFC) : const Color(0xFF030C11);
    final foreground = dark ? const Color(0xFF03171D) : Colors.white;
    return Container(
      key: const Key('home-spotlight-action'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.onPaste, required this.onSaved});

  final VoidCallback onPaste;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final actions = [
      Expanded(
        child: AppButton(
          key: const Key('home-paste-text'),
          label: 'Enter text manually',
          variant: AppButtonVariant.secondary,
          onPressed: onPaste,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: AppButton(
          label: 'Saved chats',
          variant: AppButtonVariant.secondary,
          onPressed: onSaved,
        ),
      ),
    ];
    if (!largeText) return Row(children: actions);
    return Column(
      children: [
        AppButton(
          key: const Key('home-paste-text-large'),
          label: 'Enter text manually',
          variant: AppButtonVariant.secondary,
          onPressed: onPaste,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Saved chats',
          variant: AppButtonVariant.secondary,
          onPressed: onSaved,
        ),
      ],
    );
  }
}

class _ConversationCoachPreview extends StatefulWidget {
  const _ConversationCoachPreview();

  @override
  State<_ConversationCoachPreview> createState() =>
      _ConversationCoachPreviewState();
}

class _ConversationCoachPreviewState extends State<_ConversationCoachPreview> {
  double _rotateX = 0;
  double _rotateY = 0;

  void _updateTilt(PointerEvent event) {
    if (MotionScope.reduceMotionOf(context)) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final local = box.globalToLocal(event.position);
    final normalizedX = ((local.dx / box.size.width) * 2 - 1).clamp(-1, 1);
    final normalizedY = ((local.dy / box.size.height) * 2 - 1).clamp(-1, 1);
    setState(() {
      _rotateX = -normalizedY * 0.045;
      _rotateY = normalizedX * 0.06;
    });
  }

  void _resetTilt(PointerEvent event) {
    if (_rotateX == 0 && _rotateY == 0) return;
    setState(() {
      _rotateX = 0;
      _rotateY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      excludeSemantics: true,
      label:
          'Synthetic chat preview with warm, clear and boundary-aware coaching directions',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: MouseRegion(
          onExit: _resetTilt,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: _updateTilt,
            onPointerMove: _updateTilt,
            onPointerUp: _resetTilt,
            onPointerCancel: _resetTilt,
            child: AnimatedContainer(
              key: const Key('home-3d-preview-transform'),
              duration: AppMotion.duration(context, AppMotionSpeed.fast),
              curve: AppMotion.springCurve,
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateX(_rotateX)
                ..rotateY(_rotateY),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  key: const Key('home-coach-preview'),
                  width: 340,
                  height: 282,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 44,
                        top: 22,
                        child: Container(
                          width: 250,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            gradient: RadialGradient(
                              colors: [
                                scheme.secondaryContainer.withValues(
                                  alpha: 0.88,
                                ),
                                scheme.primaryContainer.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.64, 1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 28,
                        top: 24,
                        child: Transform.rotate(
                          angle: -0.105,
                          child: const _PreviewPhone(accentRight: false),
                        ),
                      ),
                      Positioned(
                        right: 26,
                        top: 31,
                        child: Transform.rotate(
                          angle: 0.09,
                          child: const _PreviewPhone(accentRight: true),
                        ),
                      ),
                      const Positioned(
                        top: 62,
                        left: 70,
                        child: _DirectionChip(
                          label: 'Warm, not pushy',
                          tilt: -0.055,
                        ),
                      ),
                      const Positioned(
                        top: 139,
                        right: 34,
                        child: _DirectionChip(
                          label: 'A boundary, clearly',
                          tilt: 0.045,
                        ),
                      ),
                      const Positioned(
                        bottom: 18,
                        left: 54,
                        child: _DirectionChip(
                          label: 'Still your voice',
                          tilt: -0.035,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPhone extends StatelessWidget {
  const _PreviewPhone({required this.accentRight});

  final bool accentRight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 138,
      height: 205,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: context.appColors.border),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _PreviewBubble(
            alignment: accentRight
                ? Alignment.centerLeft
                : Alignment.centerRight,
            color: scheme.surfaceContainerHighest,
            width: 86,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewBubble(
            alignment: accentRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
            color: accentRight
                ? scheme.secondaryContainer
                : scheme.primaryContainer,
            width: 96,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewBubble(
            alignment: accentRight
                ? Alignment.centerLeft
                : Alignment.centerRight,
            color: scheme.surfaceContainerHighest,
            width: 72,
          ),
          const Spacer(),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.alignment,
    required this.color,
    required this.width,
  });

  final Alignment alignment;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.label, required this.tilt});

  final String label;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: tilt,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.secondaryContainer, scheme.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: scheme.surface.withValues(alpha: 0.76)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onSurface,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}
