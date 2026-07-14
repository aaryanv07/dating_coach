import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('onboarding presents value and advances between pages', (
    tester,
  ) async {
    await pumpConvoCoach(tester);

    expect(find.text('Understand every conversation.'), findsOneWidget);
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
}
