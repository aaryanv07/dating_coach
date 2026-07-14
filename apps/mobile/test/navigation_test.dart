import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('bottom navigation preserves the shell and opens create sheet', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/home');

    await tester.tap(find.text('Conversations'));
    await tester.pumpAndSettle();
    expect(find.text('A quiet start.'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('No patterns yet.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('What would help right now?'), findsOneWidget);
    expect(find.text('Analyse a conversation'), findsOneWidget);
    expect(find.text('Create a first message'), findsOneWidget);
  });
}
