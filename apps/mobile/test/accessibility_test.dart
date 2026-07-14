import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/theme/app_tokens.dart';
import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('essential age action has semantics and a large touch target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpConvoCoach(tester, initialLocation: '/age');

    expect(
      find.bySemanticsLabel('Continue after confirming age'),
      findsOneWidget,
    );
    final size = tester.getSize(find.byKey(const Key('age-continue-button')));
    expect(size.height, greaterThanOrEqualTo(AppSizes.minimumTouchTarget));
    semantics.dispose();
  });

  testWidgets('reduced motion resolves standard animations to zero', (
    tester,
  ) async {
    Duration? resolved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MotionScope(
            reduceMotion: true,
            child: Builder(
              builder: (context) {
                resolved = AppMotion.duration(context, AppMotionSpeed.normal);
                return const AppButton(label: 'Continue', onPressed: null);
              },
            ),
          ),
        ),
      ),
    );

    expect(resolved, Duration.zero);
  });

  testWidgets('onboarding remains usable at large text on a compact phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpConvoCoach(tester);

    expect(find.text('Understand every conversation.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation and settings fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await pumpConvoCoach(tester, initialLocation: '/home');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
