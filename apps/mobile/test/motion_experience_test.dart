import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_theme.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_background.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:convo_coach/core/widgets/app_vibrant_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('startup motion is brief and advances into onboarding', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/splash');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(const NoopAppHaptics())],
        child: ConvoCoachApp(router: router),
      ),
    );

    expect(find.text('ConvoCoach'), findsOneWidget);
    expect(find.byType(AppSlowRotate), findsOneWidget);

    await tester.pump(AppDurations.fast);
    expect(find.text('ConvoCoach'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Understand every conversation.'), findsOneWidget);
  });

  testWidgets('coach setup reveal honors the system motion preference', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final router = createAppRouter(initialLocation: '/onboarding');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(const NoopAppHaptics())],
        child: ConvoCoachApp(router: router),
      ),
    );
    await tester.pump();

    expect(find.text('Understand every conversation.'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled buttons provide bounded press feedback', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(const NoopAppHaptics())],
        child: const MaterialApp(
          home: MotionScope(
            reduceMotion: false,
            child: Scaffold(
              body: Center(
                child: AppButton(label: 'Continue', onPressed: _noop),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump();
    final pressed = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(pressed.scale, 0.96);
    expect(pressed.duration, AppDurations.fast);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('ocean backdrop reveals its wave field once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MotionScope(
          reduceMotion: false,
          child: AppVibrantBackdrop(child: SizedBox.expand()),
        ),
      ),
    );

    final reveal = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const Key('mermaid-wave-reveal')),
    );
    expect(reveal.duration, AppDurations.deliberate);
    expect(find.byKey(const Key('mermaid-wave-field')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ocean backdrop is static with reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MotionScope(
          reduceMotion: true,
          child: AppVibrantBackdrop(child: SizedBox.expand()),
        ),
      ),
    );

    final reveal = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const Key('mermaid-wave-reveal')),
    );
    expect(reveal.duration, Duration.zero);
    expect(find.byKey(const Key('mermaid-wave-field')), findsOneWidget);
  });

  testWidgets('GitHub home ambient motion completes and settles', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/home');

    expect(find.byType(AppBackground), findsOneWidget);
    expect(find.byType(AppFloat), findsNWidgets(2));
    expect(find.text('Level up your\nconversations.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambient and tab compatibility effects respect reduced motion', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await pumpConvoCoach(tester, initialLocation: '/home');

    expect(find.byType(AppFloat), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(AppFloat),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MotionScope(
          reduceMotion: true,
          child: AppTabTransition(index: 1, child: Text('Chats')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('tab-transition-static')), findsOneWidget);
    expect(find.byKey(const Key('tab-transition-motion')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screenshot stack becomes static with reduced motion', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await pumpConvoCoach(tester, initialLocation: '/import/screenshots');

    final stack = tester.widget<TweenAnimationBuilder<double>>(
      find.byKey(const ValueKey('screenshot-stack-0')),
    );
    expect(stack.duration, Duration.zero);
  });

  testWidgets('depth reveal is removed when motion is reduced', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MotionScope(
          reduceMotion: true,
          child: AppDepthReveal(child: Text('Coaching result')),
        ),
      ),
    );

    expect(find.text('Coaching result'), findsOneWidget);
    expect(find.byKey(const Key('app-depth-reveal-animation')), findsNothing);
  });
}

void _noop() {}
