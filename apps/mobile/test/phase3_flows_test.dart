import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('settings opens and saves the basic communication profile', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/settings');

    await tester.tap(find.text('Your profile'));
    await tester.pumpAndSettle();

    expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ari');
    expect(find.text('Job or occupation'), findsOneWidget);
    expect(find.text('Things you like'), findsOneWidget);
    expect(find.text('What you want'), findsOneWidget);
    final saveButton = find.text('Save profile');
    await tester.scrollUntilVisible(
      saveButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Profile saved.'), findsOneWidget);
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

      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Tell us what feels natural to you.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
