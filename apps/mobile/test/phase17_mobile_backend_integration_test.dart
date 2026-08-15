import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/conversation_import/domain/conversation_event.dart';
import 'package:convo_coach/features/conversations/data/http_conversation_api_client.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

const _conversationId = '00000000-0000-4000-8000-000000001700';

void main() {
  test(
    'persists only reviewed normalized data and reuses the backend UUID',
    () async {
      final requests = <_RecordedRequest>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final serverTask = _serve(server, requests);
      final client = HttpConversationApiClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        accessTokenProvider: () async => 'development-token',
      );

      final saved = await client.saveConversation(_reviewedInput());

      expect(saved.id, _conversationId);
      expect(saved.events, hasLength(2));
      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'POST /api/v1/consents',
        'POST /api/v1/conversations',
        'POST /api/v1/conversations/$_conversationId/confirm',
        'PUT /api/v1/conversations/$_conversationId/events',
      ]);
      expect(
        requests.every(
          (request) => request.authorization == 'Bearer development-token',
        ),
        isTrue,
      );
      final serializedRequests = jsonEncode(
        requests.map((request) => request.body).toList(),
      );
      expect(serializedRequests, isNot(contains('screenshot_bytes')));
      expect(serializedRequests, isNot(contains('source_path')));
      expect(serializedRequests, isNot(contains('raw_prompt')));
      expect(
        requests[2].body['messages'],
        isA<List<Object?>>().having((messages) => messages.length, 'length', 2),
      );
      await server.close(force: true);
      await serverTask;
    },
  );

  test('rejects unreviewed input before making a network request', () async {
    final client = HttpConversationApiClient(
      baseUri: Uri.parse('https://api.example.invalid'),
      accessTokenProvider: () async => 'development-token',
    );
    final reviewed = _reviewedInput();
    final invalid = SavedConversationInput(
      title: reviewed.title,
      participantName: reviewed.participantName,
      sourceType: reviewed.sourceType,
      readinessScore: reviewed.readinessScore,
      messages: reviewed.messages,
      sources: reviewed.sources,
      events: [
        _event('local-a', 0, 'user', 'First synthetic message'),
        NormalizedConversationEvent(
          id: 'local-b',
          position: 1,
          eventType: ConversationEventType.textMessage,
          speaker: 'other',
          text: 'Second synthetic message',
          timestamp: DateTime.utc(2026, 7, 27, 10, 1),
          timestampEstimated: false,
          rawTimestampText: '10:01',
          sourceImageIndex: null,
          sourceRegionId: null,
          ocrConfidence: null,
          classificationConfidence: 1,
          speakerConfidence: 1,
          timestampConfidence: 1,
          relationshipConfidence: null,
          requiresReview: true,
          metadata: const {},
          deletedAt: null,
        ),
      ],
    );

    await expectLater(
      client.saveConversation(invalid),
      throwsA(
        isA<ConversationApiException>().having(
          (error) => error.code,
          'code',
          'review_incomplete',
        ),
      ),
    );
  });

  test('obtains the bearer token at request time', () async {
    var calls = 0;
    final client = HttpConversationApiClient(
      baseUri: Uri.parse('https://api.example.invalid'),
      accessTokenProvider: () async {
        calls += 1;
        return null;
      },
    );

    await expectLater(
      client.listConversations(),
      throwsA(
        isA<ConversationApiException>().having(
          (error) => error.code,
          'code',
          'authentication_required',
        ),
      ),
    );
    expect(calls, 1);
  });
}

Future<void> _serve(HttpServer server, List<_RecordedRequest> requests) async {
  await for (final request in server) {
    final bodyBytes = <int>[];
    await for (final chunk in request) {
      bodyBytes.addAll(chunk);
    }
    final body = bodyBytes.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(utf8.decode(bodyBytes)) as Map<String, Object?>;
    requests.add(
      _RecordedRequest(
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: body,
      ),
    );

    final Object payload;
    if (request.uri.path == '/api/v1/consents') {
      request.response.statusCode = HttpStatus.created;
      payload = {'id': '00000000-0000-4000-8000-000000001701'};
    } else if (request.uri.path == '/api/v1/conversations' &&
        request.method == 'POST') {
      request.response.statusCode = HttpStatus.created;
      payload = {'id': _conversationId};
    } else if (request.uri.path.endsWith('/confirm')) {
      payload = _detailPayload();
    } else if (request.uri.path.endsWith('/events')) {
      payload = _eventsPayload();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      payload = {'detail': 'not found'};
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}

SavedConversationInput _reviewedInput() {
  return SavedConversationInput(
    title: 'Synthetic reviewed conversation',
    participantName: 'Other person',
    sourceType: 'paste',
    readinessScore: 100,
    messages: [
      NormalizedConversationMessage(
        id: 'local-a',
        speaker: 'user',
        text: 'First synthetic message',
        timestamp: DateTime.utc(2026, 7, 27, 10),
        timestampEstimated: false,
        ocrConfidence: null,
        sourceScreenshotIndex: null,
        visibleTimestampText: '10:00',
      ),
      NormalizedConversationMessage(
        id: 'local-b',
        speaker: 'other',
        text: 'Second synthetic message',
        timestamp: DateTime.utc(2026, 7, 27, 10, 1),
        timestampEstimated: false,
        ocrConfidence: null,
        sourceScreenshotIndex: null,
        visibleTimestampText: '10:01',
      ),
    ],
    sources: const [
      SavedConversationSource(
        index: 0,
        mimeType: 'text/plain',
        byteSize: null,
        storageStatus: 'not_stored',
      ),
    ],
    events: [
      _event('local-a', 0, 'user', 'First synthetic message'),
      _event('local-b', 1, 'other', 'Second synthetic message'),
    ],
  );
}

NormalizedConversationEvent _event(
  String id,
  int position,
  String speaker,
  String text,
) {
  return NormalizedConversationEvent(
    id: id,
    position: position,
    eventType: ConversationEventType.textMessage,
    speaker: speaker,
    text: text,
    timestamp: DateTime.utc(2026, 7, 27, 10, position),
    timestampEstimated: false,
    rawTimestampText: '10:0$position',
    sourceImageIndex: null,
    sourceRegionId: null,
    ocrConfidence: null,
    classificationConfidence: 1,
    speakerConfidence: 1,
    timestampConfidence: 1,
    relationshipConfidence: null,
    requiresReview: false,
    metadata: const {},
    deletedAt: null,
  );
}

Map<String, Object?> _detailPayload() {
  return {
    'id': _conversationId,
    'title': 'Synthetic reviewed conversation',
    'source_type': 'paste',
    'status': 'confirmed',
    'readiness_score': 100,
    'confirmed_at': '2026-07-27T10:02:00Z',
    'participants': [
      {
        'id': '00000000-0000-4000-8000-000000001702',
        'role': 'user',
        'display_name': 'Me',
        'position': 0,
      },
      {
        'id': '00000000-0000-4000-8000-000000001703',
        'role': 'other',
        'display_name': 'Other person',
        'position': 1,
      },
    ],
    'messages': [
      _message(
        '00000000-0000-4000-8000-000000001704',
        'user',
        'First synthetic message',
      ),
      _message(
        '00000000-0000-4000-8000-000000001705',
        'other',
        'Second synthetic message',
      ),
    ],
    'sources': [
      {
        'source_type': 'paste',
        'source_index': 0,
        'mime_type': 'text/plain',
        'byte_size': null,
        'storage_status': 'not_stored',
        'deleted_at': null,
      },
    ],
    'extraction_metadata': null,
    'created_at': '2026-07-27T10:00:00Z',
    'updated_at': '2026-07-27T10:02:00Z',
  };
}

Map<String, Object?> _message(String id, String speaker, String body) {
  return {
    'id': id,
    'participant_id': '00000000-0000-4000-8000-000000001702',
    'position': speaker == 'user' ? 0 : 1,
    'speaker': speaker,
    'body': body,
    'sent_at': '2026-07-27T10:00:00Z',
    'visible_timestamp_text': '10:00',
    'timestamp_estimated': false,
    'ocr_confidence': null,
    'source_screenshot_index': null,
    'status': 'confirmed',
    'created_at': '2026-07-27T10:02:00Z',
  };
}

Map<String, Object?> _eventsPayload() {
  return {
    'schema_version': 'conversation-events.v1',
    'compatibility_mode': 'persisted_events',
    'events': [
      _eventPayload(
        '00000000-0000-5000-8000-000000001706',
        0,
        'user',
        'First synthetic message',
      ),
      _eventPayload(
        '00000000-0000-5000-8000-000000001707',
        1,
        'other',
        'Second synthetic message',
      ),
    ],
    'relationships': <Object?>[],
  };
}

Map<String, Object?> _eventPayload(
  String id,
  int position,
  String speaker,
  String text,
) {
  return {
    'id': id,
    'conversation_id': _conversationId,
    'position': position,
    'event_type': 'text_message',
    'speaker': speaker,
    'text': text,
    'timestamp': '2026-07-27T10:00:00Z',
    'timestamp_is_estimated': false,
    'raw_timestamp_text': '10:00',
    'source_image_index': null,
    'source_region_id': null,
    'ocr_confidence': null,
    'classification_confidence': 1.0,
    'speaker_confidence': 1.0,
    'timestamp_confidence': 1.0,
    'relationship_confidence': null,
    'requires_review': false,
    'metadata': <String, Object?>{},
    'created_at': '2026-07-27T10:02:00Z',
    'updated_at': '2026-07-27T10:02:00Z',
    'deleted_at': null,
  };
}

final class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final Map<String, Object?> body;
}
