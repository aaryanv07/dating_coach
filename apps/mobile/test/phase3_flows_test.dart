import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('settings opens and saves the basic communication profile', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/settings');

    await tester.tap(find.text('Communication profile'));
    await tester.pumpAndSettle();

    expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ari');
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    expect(find.text('Communication profile saved.'), findsOneWidget);
  });

  testWidgets(
    'conversation list renders mock summaries and supports deletion',
    (tester) async {
      await pumpConvoCoach(tester, initialLocation: '/conversations');

      expect(find.text('Weekend plans'), findsOneWidget);
      expect(find.text('Sam · 18 messages'), findsOneWidget);
      expect(find.text('A synthetic hello.'), findsNothing);

      await tester.tap(find.byTooltip('Delete Weekend plans'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this conversation?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Weekend plans'), findsNothing);
      expect(find.text('Conversation deleted.'), findsOneWidget);
      expect(find.text('Coffee after work'), findsOneWidget);
    },
  );

  testWidgets(
    'Phase 3 flows remain usable with large text on a compact phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pumpConvoCoach(tester, initialLocation: '/settings/profile');

      expect(find.text('Communication profile'), findsOneWidget);
      expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
