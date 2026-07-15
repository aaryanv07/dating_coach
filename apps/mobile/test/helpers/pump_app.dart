import 'package:convo_coach/app/app.dart';
import 'package:convo_coach/app/router.dart';
import 'package:convo_coach/core/haptics/app_haptics.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/data/screenshot_picker.dart';
import 'package:convo_coach/features/conversation_import/domain/ocr_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> pumpConvoCoach(
  WidgetTester tester, {
  String initialLocation = '/onboarding',
  ConversationApiClient? conversationApiClient,
  ScreenshotPicker? screenshotPicker,
  OcrEngine? ocrEngine,
}) async {
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopAppHaptics()),
        if (conversationApiClient != null)
          conversationApiClientProvider.overrideWithValue(
            conversationApiClient,
          ),
        if (screenshotPicker != null)
          screenshotPickerProvider.overrideWithValue(screenshotPicker),
        if (ocrEngine != null) ocrEngineProvider.overrideWithValue(ocrEngine),
      ],
      child: ConvoCoachApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
