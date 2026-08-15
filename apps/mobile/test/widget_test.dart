import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('onboarding presents value and advances between pages', (
    tester,
  ) async {
    await pumpConvoCoach(tester);

    expect(find.text('Understand every conversation.'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Onboarding step 1 of 3'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Know what is working.'), findsOneWidget);
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

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Understand every conversation.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
