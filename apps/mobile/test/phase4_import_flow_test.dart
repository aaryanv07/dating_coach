import 'dart:convert';

import 'package:convo_coach/features/conversation_import/data/screenshot_picker.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets(
    'screenshot import picks multiple-capable sources and jumps to original',
    (tester) async {
      await pumpConvoCoach(
        tester,
        initialLocation: '/import/screenshots',
        screenshotPicker: _FakeScreenshotPicker(),
      );

      expect(find.byKey(const ValueKey('screenshot-stack-0')), findsOneWidget);
      expect(find.text('Extract conversation'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Upload screenshots'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Upload screenshots'));
      await tester.pumpAndSettle();
      expect(find.text('Review conversation'), findsOneWidget);
      expect(find.text('Item type'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Needs review'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Needs review'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Original 1').first,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Original 1').first);
      await tester.pumpAndSettle();
      expect(find.text('Screenshot 1'), findsOneWidget);
      expect(find.text('synthetic.png'), findsOneWidget);
    },
  );

  testWidgets('vibrant import choices remain usable with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpConvoCoach(tester, initialLocation: '/import');

    expect(find.byKey(const Key('app-vibrant-backdrop')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('import-screenshots-option')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('import-screenshots-option')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('import-paste-option')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('import-paste-option')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'paste import reviews, saves, lists, and reopens normalized messages',
    (tester) async {
      final client = MockConversationApiClient(conversations: []);
      final router = await pumpConvoCoach(
        tester,
        initialLocation: '/import',
        conversationApiClient: client,
      );

      await tester.tap(find.text('Paste conversation'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('paste-conversation-field')),
        'Other: Are we still meeting tomorrow?\nMe: Yes, noon works for me.',
      );
      await tester.tap(find.text('Review conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Review conversation'), findsOneWidget);
      expect(find.byKey(const Key('premium-review-intro')), findsOneWidget);
      expect(find.text('Ready to analyze'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('save-consent-checkbox')),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('review-message-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('confirm-save-button')),
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('review-message-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Confirm permission to continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-save-button')));
      await tester.pump();
      expect(
        find.text(
          'Choose “Keep this reviewed conversation” before continuing.',
        ),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('save-consent-checkbox')));
      await tester.pump();
      expect(find.text('Confirm and analyze'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Conversation Coach'), findsOneWidget);
      router.go('/conversations');
      await tester.pumpAndSettle();
      expect(find.text('Imported conversation'), findsOneWidget);
      await tester.tap(find.text('Imported conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Saved conversation'), findsOneWidget);
      expect(find.text('Are we still meeting tomorrow?'), findsOneWidget);
      expect(find.text('Yes, noon works for me.'), findsOneWidget);
      expect(find.text('View conversation data'), findsNothing);
    },
  );

  testWidgets(
    'review studio exposes accessible message and readiness semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpConvoCoach(tester, initialLocation: '/import/paste');
      await tester.enterText(
        find.byKey(const Key('paste-conversation-field')),
        'Other: First synthetic message\nMe: Second synthetic message',
      );
      await tester.ensureVisible(find.text('Review conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review conversation'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          'Conversation is ready to analyze after confirmation.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(RegExp(r'Event 1, Text message, Other person')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Event 1, Text message, Other person')),
        findsOneWidget,
      );
      final undoSize = tester.getSize(find.byTooltip('Undo'));
      expect(undoSize.width, greaterThanOrEqualTo(44));
      expect(undoSize.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    },
  );

  testWidgets(
    'review studio remains usable with large text on a compact phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        debugDefaultTargetPlatformOverride = null;
      });

      await pumpConvoCoach(tester, initialLocation: '/import/paste');
      await tester.enterText(
        find.byKey(const Key('paste-conversation-field')),
        'Other: First synthetic message\nMe: Second synthetic message',
      );
      await tester.scrollUntilVisible(
        find.text('Review conversation'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Review conversation'), findsOneWidget);
      expect(find.byKey(const Key('app-vibrant-backdrop')), findsOneWidget);
      expect(find.byKey(const Key('premium-review-intro')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('premium-readiness-panel')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('premium-readiness-panel')), findsOneWidget);
      final exception = tester.takeException();
      debugDefaultTargetPlatformOverride = null;
      expect(exception, isNull);
    },
  );
}

class _FakeScreenshotPicker implements ScreenshotPicker {
  @override
  Future<List<TemporaryImportSource>> pick({required int startingIndex}) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    return [
      TemporaryImportSource(
        metadata: ImportSourceMetadata(
          id: 'synthetic-source',
          name: 'synthetic.png',
          mimeType: 'image/png',
          byteSize: bytes.length,
          index: startingIndex,
        ),
        bytes: bytes,
      ),
    ];
  }
}
