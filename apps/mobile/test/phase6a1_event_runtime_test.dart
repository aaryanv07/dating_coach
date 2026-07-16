import 'package:convo_coach/features/conversation_import/application/conversation_import_controller.dart';
import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversation_import/domain/event_classifier.dart';
import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:convo_coach/features/conversation_import/domain/normalizer.dart';
import 'package:convo_coach/features/conversation_import/domain/overlap_detector.dart';
import 'package:convo_coach/features/conversation_import/domain/readiness.dart';
import 'package:convo_coach/features/conversation_import/domain/review_message.dart';
import 'package:convo_coach/features/conversation_import/domain/screenshot_ordering.dart';
import 'package:convo_coach/features/conversations/data/conversation_event_dto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifier distinguishes attached reaction from emoji message', () {
    const classifier = DeterministicConversationEventClassifier();
    final events = classifier.classify([
      _region(
        text: 'Coffee tomorrow?',
        order: 0,
        bounds: const OcrBounds(left: 100, top: 100, right: 320, bottom: 170),
        speaker: MessageSpeaker.other,
      ),
      _region(
        text: '❤',
        order: 1,
        bounds: const OcrBounds(left: 265, top: 158, right: 290, bottom: 180),
        speaker: MessageSpeaker.me,
      ),
      _region(
        text: '😂',
        order: 2,
        bounds: const OcrBounds(left: 500, top: 300, right: 535, bottom: 338),
        speaker: MessageSpeaker.me,
      ),
    ]);

    expect(events.map((event) => event.eventType), [
      ConversationEventType.textMessage,
      ConversationEventType.reaction,
      ConversationEventType.emojiMessage,
    ]);
    expect(events[1].countsAsMessage, isFalse);
    expect(events[1].relationshipTargetId, events[0].id);
    expect(events[1].speaker, MessageSpeaker.unknown);
    expect(events[1].needsReview, isTrue);
    expect(events[2].countsAsMessage, isTrue);
  });

  test('overlap deduplication keeps reaction and emoji roles distinct', () {
    const detector = BoundaryOverlapDetector();
    final result = detector.removeDuplicates([
      ExtractedScreenshot(
        sourceIndex: 0,
        regions: [
          _region(
            text: '❤',
            order: 0,
            bounds: const OcrBounds(
              left: 260,
              top: 160,
              right: 290,
              bottom: 182,
            ),
            speaker: MessageSpeaker.me,
          ).copyWith(compactAttachmentHint: true),
        ],
      ),
      ExtractedScreenshot(
        sourceIndex: 1,
        regions: [
          _region(
            text: '❤',
            order: 0,
            bounds: const OcrBounds(
              left: 500,
              top: 300,
              right: 535,
              bottom: 338,
            ),
            speaker: MessageSpeaker.me,
          ).copyWith(compactAttachmentHint: false),
        ],
      ),
    ]);

    expect(result.regions, hasLength(2));
    expect(result.removedCount, 0);
  });

  test(
    'normalization is deterministic and never projects reactions as messages',
    () {
      final relationship = ConversationEventRelationship(
        id: 'relationship-1',
        sourceEventId: 'reaction-1',
        targetEventId: 'message-1',
        type: ConversationEventRelationshipType.reactionTarget,
        confidence: 1,
      );
      final reviewEvents = [
        _reviewEvent(
          id: 'date-1',
          type: ConversationEventType.dateSeparator,
          speaker: MessageSpeaker.system,
          text: 'Today',
        ),
        _reviewEvent(
          id: 'message-1',
          type: ConversationEventType.textMessage,
          speaker: MessageSpeaker.other,
          text: 'Coffee tomorrow?',
        ),
        _reviewEvent(
          id: 'reaction-1',
          type: ConversationEventType.reaction,
          speaker: MessageSpeaker.me,
          text: '❤',
          relationships: [relationship],
        ),
        _reviewEvent(
          id: 'message-2',
          type: ConversationEventType.emojiMessage,
          speaker: MessageSpeaker.me,
          text: '😂',
        ),
      ];

      final first = ConversationNormalizer.normalize(
        title: ' Synthetic events ',
        importType: ConversationImportType.screenshot,
        readinessScore: 95,
        messages: reviewEvents,
        sources: const [
          ImportSourceMetadata(
            id: 'source-1',
            name: 'Synthetic source',
            mimeType: 'image/png',
            byteSize: 1200,
            index: 0,
          ),
        ],
      );
      final second = ConversationNormalizer.normalize(
        title: ' Synthetic events ',
        importType: ConversationImportType.screenshot,
        readinessScore: 95,
        messages: reviewEvents,
        sources: const [
          ImportSourceMetadata(
            id: 'source-1',
            name: 'Synthetic source',
            mimeType: 'image/png',
            byteSize: 1200,
            index: 0,
          ),
        ],
      );
      final firstDto = ConversationEventSequenceDto(
        events: first.events
            .map((event) => ConversationEventDto(event: event))
            .toList(),
        relationships: first.relationships
            .map(
              (relationship) =>
                  ConversationEventRelationshipDto(relationship: relationship),
            )
            .toList(),
      );
      final secondDto = ConversationEventSequenceDto(
        events: second.events
            .map((event) => ConversationEventDto(event: event))
            .toList(),
        relationships: second.relationships
            .map(
              (relationship) =>
                  ConversationEventRelationshipDto(relationship: relationship),
            )
            .toList(),
      );

      expect(first.title, 'Synthetic events');
      expect(first.events, hasLength(4));
      expect(first.messages.map((message) => message.id), [
        'message-1',
        'message-2',
      ]);
      expect(first.relationships.single.targetEventId, 'message-1');
      expect(firstDto.toJson(), secondDto.toJson());
      final encoded = firstDto.toJson();
      final eventJson = encoded['events']! as List<Map<String, Object?>>;
      final relationshipJson =
          encoded['relationships']! as List<Map<String, Object?>>;
      expect(
        eventJson.first['id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(relationshipJson.single['source_event_id'], eventJson[2]['id']);
      expect(relationshipJson.single['target_event_id'], eventJson[1]['id']);
      final decoded = ConversationEventSequenceDto.fromJson(encoded);
      expect(decoded.events[2].event.eventType, ConversationEventType.reaction);
      expect(
        decoded.relationships.single.relationship.type,
        ConversationEventRelationshipType.reactionTarget,
      );
    },
  );

  test(
    'readiness blocks unresolved events without counting them as messages',
    () {
      final base = [
        _reviewEvent(
          id: 'message-1',
          type: ConversationEventType.textMessage,
          speaker: MessageSpeaker.other,
          text: 'Hello',
        ),
        _reviewEvent(
          id: 'message-2',
          type: ConversationEventType.textMessage,
          speaker: MessageSpeaker.me,
          text: 'Hi',
        ),
        _reviewEvent(
          id: 'unknown-1',
          type: ConversationEventType.unknown,
          speaker: MessageSpeaker.unknown,
          text: '?',
          requiresReview: true,
        ),
      ];

      final unresolved = ConversationReadiness.evaluate(base);
      final resolved = ConversationReadiness.evaluate(base.sublist(0, 2));

      expect(unresolved.isReady, isFalse);
      expect(resolved.isReady, isTrue);
      expect(
        unresolved.checks
            .firstWhere((check) => check.label == 'Missing messages')
            .passed,
        isTrue,
      );
    },
  );

  test('Riverpod event edits keep immutable snapshots and a 50-step bound', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(conversationImportProvider.notifier);
    expect(
      controller.parsePaste(
        'Other: First synthetic message\nMe: Second synthetic message',
      ),
      isTrue,
    );
    final original = container.read(conversationImportProvider).events;

    controller.changeEventType('paste-0', ConversationEventType.reaction);
    expect(
      container.read(conversationImportProvider).events.first.needsReview,
      isTrue,
    );
    controller.attachEventRelationship('paste-0', 'paste-1');
    expect(
      container.read(conversationImportProvider).events.first.needsReview,
      isFalse,
    );
    expect(original.first.eventType, ConversationEventType.textMessage);

    for (var index = 0; index < 55; index++) {
      controller.editMessage('paste-1', 'Edited synthetic message $index');
    }
    expect(container.read(conversationImportProvider).past, hasLength(50));
    controller.undo();
    expect(
      container.read(conversationImportProvider).events[1].text,
      'Edited synthetic message 53',
    );
  });
}

CandidateMessageRegion _region({
  required String text,
  required int order,
  required OcrBounds bounds,
  required MessageSpeaker speaker,
}) {
  return CandidateMessageRegion(
    text: text,
    bounds: bounds,
    confidence: 0.95,
    sourceIndex: 0,
    sourceOrder: order,
    speaker: speaker,
    pageWidth: 720,
  );
}

ReviewMessage _reviewEvent({
  required String id,
  required ConversationEventType type,
  required MessageSpeaker speaker,
  required String text,
  List<ConversationEventRelationship> relationships = const [],
  bool requiresReview = false,
}) {
  return ReviewMessage(
    id: id,
    speaker: speaker,
    text: text,
    timestamp: null,
    timestampEstimated: false,
    ocrConfidence: 1,
    sourceScreenshotIndex: 0,
    status: ReviewMessageStatus.edited,
    eventType: type,
    classificationConfidence: 1,
    speakerConfidence: 1,
    relationshipConfidence: relationships.isEmpty ? null : 1,
    requiresReview: requiresReview,
    relationships: relationships,
  );
}
