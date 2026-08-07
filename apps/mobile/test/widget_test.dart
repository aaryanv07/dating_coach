import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('onboarding presents value and advances between pages', (
    tester,
  ) async {
    await pumpConvoCoach(tester);

    expect(find.text('START WITH\nYOUR VOICE'), findsOneWidget);
    expect(
      find.byKey(const Key('immersive-onboarding-background')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('coach-style-hero')), findsOneWidget);
    expect(find.byKey(const Key('coach-style-card-warm')), findsOneWidget);
    expect(find.byKey(const Key('coach-style-card-direct')), findsOneWidget);
    expect(find.text('Onboarding step 1 of 3'), findsNothing);

    await tester.tap(find.text('Start exploring'));
    await tester.pumpAndSettle();

    expect(find.text('READ THE PATTERN,\nNOT THEIR MIND'), findsOneWidget);
  });

  testWidgets('skip keeps privacy and age essentials in the flow', (
    tester,
  ) async {
    await pumpConvoCoach(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Private by design.'), findsOneWidget);
  });

  testWidgets('immersive onboarding remains usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpConvoCoach(tester);

    expect(
      find.byKey(const Key('immersive-onboarding-background')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('coach-style-hero')), findsOneWidget);
    expect(find.text('START WITH\nYOUR VOICE'), findsOneWidget);
    expect(find.text('Start exploring'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
