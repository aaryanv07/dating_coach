import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> pumpConvoCoach(
  WidgetTester tester, {
  String initialLocation = '/onboarding',
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(const NoopAppHaptics())],
      child: ConvoCoachApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
