import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'dart:math' as math;

import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_gradient_text.dart';
import 'package:convo_coach/core/widgets/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: 'COACH SETUP',
      title: 'START WITH\nYOUR VOICE',
      body:
          'Shape coaching around how you communicate. You keep the final word, every time.',
      visual: _CoachCalibrationVisual(),
    ),
    _OnboardingPageData(
      eyebrow: 'CLEAR SIGNALS',
      title: 'READ THE PATTERN,\nNOT THEIR MIND',
      body:
          'See observable reciprocity, momentum and clarity—with uncertainty kept visible.',
      visual: _MetricsVisual(),
    ),
    _OnboardingPageData(
      eyebrow: 'YOUR DECISION',
      title: 'DRAFTS THAT STILL\nSOUND LIKE YOU',
      body:
          'Explore a few honest directions, edit freely and choose whether to send anything.',
      visual: _ReplyVisual(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    ref.read(hapticsProvider).selection();
    if (_pageIndex == _pages.length - 1) {
      if (mounted) context.go('/privacy');
      return;
    }
    await _pageController.animateToPage(
      _pageIndex + 1,
      duration: AppMotion.duration(context, AppMotionSpeed.deliberate),
      curve: AppMotion.standardCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryGlow = _pageIndex.isEven
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final secondaryGlow = _pageIndex == 1
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    return Scaffold(
      body: AnimatedContainer(
        key: const Key('immersive-onboarding-background'),
        duration: AppMotion.duration(context, AppMotionSpeed.normal),
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.46, 1],
            colors: [
              primaryGlow.withValues(alpha: 0.78),
              scheme.surface,
              secondaryGlow.withValues(alpha: 0.34),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: _BackdropGlow(
                size: 280,
                color: scheme.primary.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -140,
              child: _BackdropGlow(
                size: 320,
                color: scheme.secondary.withValues(alpha: 0.1),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: BrandLockup(compact: true),
                          ),
                        ),
                        Semantics(
                          label:
                              'Onboarding step ${_pageIndex + 1} of ${_pages.length}',
                          child: ExcludeSemantics(
                            child: _CompactStepIndicator(
                              currentIndex: _pageIndex,
                              count: _pages.length,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'Skip',
                          expand: false,
                          variant: AppButtonVariant.quiet,
                          onPressed: () => context.go('/privacy'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      itemBuilder: (context, index) {
                        return _OnboardingPage(data: _pages[index]);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        _ProgressSegments(
                          currentIndex: _pageIndex,
                          count: _pages.length,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: _pageIndex == _pages.length - 1
                              ? 'Continue privately'
                              : 'Start exploring',
                          icon: Icons.arrow_forward_rounded,
                          semanticLabel: 'Continue onboarding',
                          onPressed: _nextPage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget visual;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final useScrollableLayout =
            textScale > 1.3 || constraints.maxHeight < 560;
        final visual = Center(
          child: AppReveal(offset: const Offset(0, 8), child: data.visual),
        );
        final copy = Align(
          alignment: landscape ? Alignment.centerLeft : Alignment.topLeft,
          child: AppReveal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.eyebrow,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppGradientText(
                  data.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 0.98,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(data.body, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        );

        Widget content;
        if (useScrollableLayout) {
          content = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 190, child: visual),
                const SizedBox(height: AppSpacing.lg),
                copy,
              ],
            ),
          );
        } else if (landscape) {
          content = Row(
            children: [
              Expanded(child: visual),
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: copy),
            ],
          );
        } else {
          content = Column(
            children: [
              Expanded(flex: 5, child: visual),
              Expanded(flex: 5, child: copy),
            ],
          );
        }

        return Semantics(
          container: true,
          label: data.title,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: content,
          ),
        );
      },
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

class _CompactStepIndicator extends StatelessWidget {
  const _CompactStepIndicator({
    required this.currentIndex,
    required this.count,
  });

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: AppMotion.duration(context, AppMotionSpeed.fast),
          curve: AppMotion.standardCurve,
          width: active ? 24 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        );
      }),
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({required this.currentIndex, required this.count});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding step ${currentIndex + 1} of $count',
      child: Row(
        children: List.generate(count, (index) {
          final active = index <= currentIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotionSpeed.fast),
              height: 4,
              margin: EdgeInsets.only(
                right: index == count - 1 ? 0 : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : context.appColors.border,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CoachCalibrationVisual extends StatelessWidget {
  const _CoachCalibrationVisual();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      excludeSemantics: true,
      label:
          'A coaching-style preview with warm and direct response directions',
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            key: const Key('coach-style-hero'),
            width: 320,
            height: 380,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 300),
                ),
                TweenAnimationBuilder<double>(
                  key: const Key('coach-style-hero-entry'),
                  duration: AppMotion.duration(
                    context,
                    AppMotionSpeed.deliberate,
                  ),
                  curve: AppMotion.springCurve,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: Transform.scale(
                          scale: 0.92 + (0.08 * value),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Transform.rotate(
                    angle: -math.pi / 90,
                    child: Container(
                      width: 270,
                      height: 362,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.surfaceContainerHighest,
                            scheme.primaryContainer,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: context.appColors.border.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.lock_outline_rounded, size: 18),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'How would you like to sound?',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '“Want to continue this over coffee?”',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Transform.rotate(
                                  angle: -0.035,
                                  child: _StyleDirectionCard(
                                    key: Key('coach-style-card-warm'),
                                    index: '01',
                                    label: 'Warm & curious',
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Transform.rotate(
                                  angle: 0.035,
                                  child: _StyleDirectionCard(
                                    key: Key('coach-style-card-direct'),
                                    index: '02',
                                    label: 'Clear & direct',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Center(
                            child: Text(
                              'YOUR VOICE • YOUR CHOICE',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _StyleDirectionCard extends StatelessWidget {
  const _StyleDirectionCard({
    required this.index,
    required this.label,
    super.key,
  });

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(index, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              label,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsVisual extends StatelessWidget {
  const _MetricsVisual();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Explainable conversation metrics',
      child: SizedBox(
        width: 300,
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _MetricRow(label: 'Reciprocity', value: 0.78),
              SizedBox(height: AppSpacing.lg),
              _MetricRow(label: 'Momentum', value: 0.62),
              SizedBox(height: AppSpacing.lg),
              _MetricRow(label: 'Clarity', value: 0.88),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          duration: AppMotion.duration(context, AppMotionSpeed.normal),
          curve: AppMotion.standardCurve,
          tween: Tween(begin: 0, end: value),
          builder: (context, animatedValue, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: LinearProgressIndicator(
                value: animatedValue,
                minHeight: 8,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReplyVisual extends StatelessWidget {
  const _ReplyVisual();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Natural, playful and direct reply directions',
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _ReplyCard(
              label: 'Natural',
              icon: Icons.chat_bubble_outline_rounded,
            ),
            SizedBox(height: AppSpacing.md),
            _ReplyCard(label: 'Playful', icon: Icons.auto_awesome_outlined),
            SizedBox(height: AppSpacing.md),
            _ReplyCard(label: 'Direct', icon: Icons.north_east_rounded),
          ],
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}
