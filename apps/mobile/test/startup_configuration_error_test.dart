import 'package:convo_coach/app/configuration_error_app.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invalid release configuration renders a safe visible failure', (
    tester,
  ) async {
    await tester.pumpWidget(const ConvoCoachConfigurationErrorApp());
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('This build needs configuration.'), findsOneWidget);
    expect(
      find.text(
        'Install a configured build before connecting an account or private conversation.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('release_'), findsNothing);
  });
}
