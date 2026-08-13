import 'package:convo_coach/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('privacy, age, authentication and profile setup gate home', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/privacy');

    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.text('For adults, with adult boundaries.'), findsOneWidget);

    var continueButton = tester.widget<AppButton>(
      find.byKey(const Key('age-continue-button')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('age-confirmation-checkbox')));
    await tester.pump();
    continueButton = tester.widget<AppButton>(
      find.byKey(const Key('age-continue-button')),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('age-continue-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your space in'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Ari');
    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.enterText(find.byType(TextField).at(4), 'music');
    final saveProfile = find.text('Save profile');
    await tester.scrollUntilVisible(
      saveProfile,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveProfile);
    await tester.pumpAndSettle();
    expect(find.text('Level up your\nconversations.'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });
}
