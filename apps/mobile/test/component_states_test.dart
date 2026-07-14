import 'package:convo_coach/core/motion/app_motion.dart';
import 'package:convo_coach/core/widgets/app_skeleton.dart';
import 'package:convo_coach/core/widgets/app_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'empty, error and offline states communicate without color alone',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: AppEmptyState(
                    title: 'Nothing yet',
                    message: 'Start when ready.',
                  ),
                ),
                Expanded(
                  child: AppErrorState(
                    title: 'Could not load',
                    message: 'Try again safely.',
                  ),
                ),
                Expanded(child: AppOfflineState()),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('You are offline'), findsOneWidget);
    },
  );

  testWidgets('skeleton becomes static when motion is reduced', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MotionScope(
          reduceMotion: true,
          child: Scaffold(body: AppSkeleton(height: 24)),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
