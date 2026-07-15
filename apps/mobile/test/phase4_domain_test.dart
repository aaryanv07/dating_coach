import 'dart:typed_data';

import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/data/temporary_source_store.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:convo_coach/features/conversation_import/domain/readiness.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversations/application/conversation_list_controller.dart';
import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer createContainer({
    MockConversationApiClient? conversationClient,
    InMemoryTemporarySourceStore? sourceStore,
  }) {
    final container = ProviderContainer(
      overrides: [
        conversationApiClientProvider.overrideWithValue(
          conversationClient ?? MockConversationApiClient(conversations: []),
        ),
        if (sourceStore != null)
          temporarySourceStoreProvider.overrideWithValue(sourceStore),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('readiness is data quality and flags unresolved low-confidence OCR', () {
    final messages = [
      _message('one', MessageSpeaker.other, confidence: 0.98),
      _message('two', MessageSpeaker.me, confidence: 0.74),
    ];

    final unresolved = ConversationReadiness.evaluate(messages);
    final reviewed = ConversationReadiness.evaluate([
      messages.first,
      messages.last.copyWith(status: ReviewMessageStatus.edited),
    ]);

    expect(unresolved.isReady, isFalse);
    expect(
      unresolved.checks
          .firstWhere((check) => check.label == 'OCR confidence')
          .passed,
      isFalse,
    );
    expect(reviewed.isReady, isTrue);
    expect(
      reviewed.score,
      greaterThanOrEqualTo(conversationReadinessThreshold),
    );
  });

  test('readiness blocks an out-of-order screenshot sequence', () {
    final report = ConversationReadiness.evaluate([
      _message('later', MessageSpeaker.other, sourceIndex: 1),
      _message('earlier', MessageSpeaker.me, sourceIndex: 0),
    ]);

    expect(report.isReady, isFalse);
    expect(
      report.checks
          .firstWhere((check) => check.label == 'Screenshot order')
          .passed,
      isFalse,
    );
  });

  test(
    'editor supports merge, split, speaker swap, delete, restore, undo, and redo',
    () async {
      final container = createContainer();
      final controller = container.read(conversationImportProvider.notifier);
      await controller.start(ConversationImportType.paste);
      expect(
        controller.parsePaste(
          'Other: Hello there\nMe: Hi back\nOther: Tomorrow?',
        ),
        isTrue,
      );
      final initial = container.read(conversationImportProvider).messages;

      controller.mergeWithNext(initial.first.id);
      expect(
        container.read(conversationImportProvider).messages.first.text,
        'Hello there Hi back',
      );
      expect(
        container.read(conversationImportProvider).messages[1].status,
        ReviewMessageStatus.deleted,
      );

      controller.undo();
      expect(
        container.read(conversationImportProvider).messages[1].isDeleted,
        isFalse,
      );
      controller.redo();
      expect(
        container.read(conversationImportProvider).messages[1].isDeleted,
        isTrue,
      );
      controller.undo();

      final firstId = container
          .read(conversationImportProvider)
          .messages
          .first
          .id;
      expect(controller.splitMessage(firstId, 5), isTrue);
      expect(
        container.read(conversationImportProvider).messages.first.text,
        'Hello',
      );
      expect(
        container.read(conversationImportProvider).messages[1].text,
        'there',
      );

      controller.swapSpeaker(firstId);
      expect(
        container.read(conversationImportProvider).messages.first.speaker,
        MessageSpeaker.me,
      );
      controller.deleteMessage(firstId);
      expect(
        container.read(conversationImportProvider).messages.first.isDeleted,
        isTrue,
      );
      controller.restoreMessage(firstId);
      expect(
        container.read(conversationImportProvider).messages.first.isDeleted,
        isFalse,
      );
    },
  );

  test(
    'duplicate and move operations preserve editable message blocks',
    () async {
      final container = createContainer();
      final controller = container.read(conversationImportProvider.notifier);
      await controller.start(ConversationImportType.paste);
      controller.parsePaste('Other: First\nMe: Second\nOther: Third');
      final firstId = container
          .read(conversationImportProvider)
          .messages
          .first
          .id;

      controller.duplicateMessage(firstId);
      expect(container.read(conversationImportProvider).messages, hasLength(4));
      expect(
        container.read(conversationImportProvider).messages[1].text,
        'First',
      );

      controller.moveMessage(firstId, 1);
      expect(
        container.read(conversationImportProvider).messages[1].id,
        firstId,
      );
    },
  );

  test(
    'normalization removes deleted and empty content and preserves source links',
    () {
      final normalized = ConversationNormalizer.normalize(
        title: '  Synthetic chat  ',
        importType: ConversationImportType.screenshot,
        readinessScore: 92,
        messages: [
          _message('  Hello   there ', MessageSpeaker.other, sourceIndex: 0),
          _message(
            'discard',
            MessageSpeaker.me,
          ).copyWith(status: ReviewMessageStatus.deleted),
        ],
        sources: const [
          ImportSourceMetadata(
            id: 'source-0',
            name: 'synthetic.png',
            mimeType: 'image/png',
            byteSize: 128,
            index: 0,
          ),
        ],
      );

      expect(normalized.title, 'Synthetic chat');
      expect(normalized.messages, hasLength(1));
      expect(normalized.messages.single.text, 'Hello there');
      expect(normalized.messages.single.sourceScreenshotIndex, 0);
      expect(normalized.sources.single.storageStatus, 'deleted');
    },
  );

  test(
    'confirmed persistence clears temporary sources and can reopen the saved item',
    () async {
      final sourceStore = InMemoryTemporarySourceStore();
      final client = MockConversationApiClient(conversations: []);
      final container = createContainer(
        conversationClient: client,
        sourceStore: sourceStore,
      );
      final controller = container.read(conversationImportProvider.notifier);
      await controller.start(ConversationImportType.screenshot);
      await controller.addSources([
        TemporaryImportSource(
          metadata: const ImportSourceMetadata(
            id: 'source-0',
            name: 'synthetic.png',
            mimeType: 'image/png',
            byteSize: 4,
            index: 0,
          ),
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ]);
      expect(await controller.extractScreenshots(), isTrue);
      final lowConfidence = container
          .read(conversationImportProvider)
          .messages
          .firstWhere((message) => message.needsReview);
      controller.editMessage(lowConfidence.id, lowConfidence.text);
      controller.setSaveConsent(true);

      final saved = await controller.save();

      expect(saved, isNotNull);
      expect(await sourceStore.readAll(), isEmpty);
      expect((await client.getConversation(saved!.id))?.messages, hasLength(2));
      expect((await client.listConversations()).single.id, saved.id);
    },
  );
}

ReviewMessage _message(
  String text,
  MessageSpeaker speaker, {
  double? confidence = 0.98,
  int? sourceIndex,
}) {
  return ReviewMessage(
    id: '$text-${speaker.name}',
    speaker: speaker,
    text: text,
    timestamp: DateTime.utc(2026, 7, 14, 10),
    timestampEstimated: false,
    ocrConfidence: confidence,
    sourceScreenshotIndex: sourceIndex,
    status: ReviewMessageStatus.extracted,
  );
}
