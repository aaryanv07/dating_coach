import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets(
    'GitHub navigation preserves production routes and create sheet',
    (tester) async {
      await pumpConvoCoach(tester, initialLocation: '/home');

      expect(find.text('Level up your\nconversations.'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);

      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(find.text('Weekend plans'), findsOneWidget);

      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Overall stats'), findsOneWidget);
      expect(find.byKey(const Key('overall-score-hero')), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('What would help right now?'), findsOneWidget);
      expect(find.text('Import conversation'), findsOneWidget);
      expect(find.text('Profile screenshot'), findsOneWidget);
    },
  );

  testWidgets('sign out is explicit and returns to authentication', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/profile');

    await tester.scrollUntilVisible(
      find.byKey(const Key('sign-out-action')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('sign-out-action')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your space in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('profile exposes an explicit owner-controlled data export', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/profile');

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-account-action')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('export-account-action')));
    await tester.pumpAndSettle();

    expect(find.text('Export your data?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-account-export')), findsOneWidget);
  });
}
