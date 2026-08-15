import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  test('approved preview catalog keeps pricing and allowances explicit', () {
    expect(SubscriptionCatalog.free.monthlyPriceInr, 0);
    expect(SubscriptionCatalog.plus.monthlyPriceInr, 999);
    expect(SubscriptionCatalog.plus.yearlyPriceInr, 8999);
    expect(SubscriptionCatalog.plus.effectiveYearlyMonthlyPriceInr, 750);
    expect(
      SubscriptionCatalog.plus.allowances,
      contains(
        isA<PlanAllowance>()
            .having((item) => item.label, 'label', 'Conversation analyses')
            .having((item) => item.detail, 'detail', '12 each month'),
      ),
    );
  });

  testWidgets('profile opens a truthful non-purchasing plan preview', (
    tester,
  ) async {
    await pumpConvoCoach(tester, initialLocation: '/profile');

    await tester.tap(find.text('Plan and usage'));
    await tester.pumpAndSettle();

    expect(find.text('30-day welcome allowance'), findsOneWidget);
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -900),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('ELLIS Plus'), findsOneWidget);
    expect(find.text('₹999 / month'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    expect(find.text('₹8,999 / year'), findsOneWidget);
    expect(find.text('About ₹750 per month'), findsOneWidget);
    await tester.fling(
      find.byType(Scrollable).last,
      const Offset(0, -500),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Purchases unavailable in this build'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan preview remains usable at large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpConvoCoach(tester, initialLocation: '/profile/subscription');

    expect(find.text('Choose coaching that fits your pace.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
