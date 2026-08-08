import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('simplified bottom navigation preserves the four core spaces', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/home');

    expect(
      find.byKey(const Key('simplified-bottom-navigation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tab-transition-motion')), findsOneWidget);
    expect(find.byKey(const Key('home-vibrant-headline')), findsOneWidget);
    expect(find.text('Create'), findsNothing);

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Weekend plans'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Overall stats'), findsOneWidget);
    expect(find.byKey(const Key('overall-score-hero')), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('home opens screenshot import in one primary action', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/home');

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-upload-screenshots')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home-upload-screenshots')));
    await tester.pumpAndSettle();

    expect(find.text('Add screenshots'), findsOneWidget);
    expect(find.byKey(const ValueKey('screenshot-stack-0')), findsOneWidget);
  });

  testWidgets('premium home header keeps menu and quick upload functional', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/home');

    expect(find.byKey(const Key('navigation-home')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-menu-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-quick-menu')), findsOneWidget);
    expect(find.text('Saved chats'), findsWidgets);
    expect(find.text('Overall stats'), findsOneWidget);

    await tester.tap(find.text('Overall stats'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overall-score-hero')), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-spotlight-action')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-spotlight-action')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-private-review-pill')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-private-review-pill')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-new-chat-action')));
    await tester.pumpAndSettle();
    expect(find.text('Add screenshots'), findsOneWidget);
  });

  testWidgets('vibrant home stays usable with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpConvoCoach(tester, initialLocation: '/home');

    expect(find.byKey(const Key('app-vibrant-backdrop')), findsOneWidget);
    expect(find.byKey(const Key('home-vibrant-headline')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-upload-screenshots')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-upload-screenshots')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign out is explicit and returns to authentication', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/settings');

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

  testWidgets('settings exposes an explicit owner-controlled data export', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/settings');

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
