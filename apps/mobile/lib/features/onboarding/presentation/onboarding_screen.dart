import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_colors.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_brand.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
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
      title: 'Understand every conversation.',
      body:
          'See observable patterns without pretending to read someone else\'s mind.',
      visual: _ConversationVisual(),
    ),
    _OnboardingPageData(
      title: 'Know what is working.',
      body:
          'Turn reciprocity, momentum and clarity into calm, explainable guidance.',
      visual: _MetricsVisual(),
    ),
    _OnboardingPageData(
      title: 'Replies that still sound like you.',
      body:
          'Choose a direction, keep your voice and make every final decision yourself.',
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
    return Scaffold(
      body: SafeArea(
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
                onPageChanged: (index) => setState(() => _pageIndex = index),
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
                        : 'Continue',
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
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.visual,
  });

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
                  data.title,
                  style: Theme.of(context).textTheme.displaySmall,
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

class _ConversationVisual extends StatelessWidget {
  const _ConversationVisual();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'A balanced conversation with clear back and forth',
      child: SizedBox(
        width: 300,
        height: 260,
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 0,
              right: 56,
              child: _MessageBubble(
                text: 'That sounds like a story worth hearing.',
                color: scheme.surfaceContainerHighest,
              ),
            ),
            Positioned(
              top: 94,
              left: 48,
              right: 0,
              child: _MessageBubble(
                text: 'Only if you share your weekend plot twist too.',
                color: scheme.primaryContainer,
              ),
            ),
            Positioned(
              top: 178,
              left: 8,
              right: 78,
              child: _MessageBubble(
                text: 'Deal. Mine involved a very ambitious train plan.',
                color: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
