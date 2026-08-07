import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/conversations/data/conversation_api_client.dart';
import 'package:convo_coach/features/conversations/data/conversation_event_dto.dart';
import 'package:convo_coach/features/conversations/data/conversation_summary_dto.dart';
import 'package:convo_coach/features/conversations/data/saved_conversation_dto.dart';
import 'package:convo_coach/features/conversations/domain/saved_conversation.dart';

const _maximumResponseBytes = 1024 * 1024;
const _historyConsentPolicyVersion = 'conversation-history-v1';

final class ConversationApiException implements Exception {
  const ConversationApiException({required this.code, this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'ConversationApiException($code)';
}

/// Authenticated owner-scoped conversation transport.
///
/// Only normalized, explicitly reviewed data crosses this boundary. Source
/// image bytes and paths are never accepted by this client.
final class HttpConversationApiClient implements ConversationApiClient {
  HttpConversationApiClient({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Uri baseUri;
  final Future<String?> Function() accessTokenProvider;
  final HttpClient Function() _clientFactory;

  @override
  Future<List<ConversationSummaryDto>> listConversations() async {
    final payload = await _requestJson('GET', '/api/v1/conversations');
    if (payload is! List<Object?>) {
      throw const ConversationApiException(code: 'response_invalid');
    }
    return payload
        .map(
          (item) => ConversationSummaryDto.fromJson(
            _object(item, code: 'conversation_summary_invalid'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _request(
      'DELETE',
      '/api/v1/conversations/${Uri.encodeComponent(conversationId)}',
      expectedStatuses: const {HttpStatus.noContent},
    );
  }

  @override
  Future<SavedConversationDto> saveConversation(
    SavedConversationInput input,
  ) async {
    _validateReviewedInput(input);
    await _requestJson(
      'POST',
      '/api/v1/consents',
      body: {
        'consent_type': 'save_conversation_history',
        'granted': true,
        'policy_version': _historyConsentPolicyVersion,
      },
      expectedStatuses: const {HttpStatus.created},
    );

    final created = _object(
      await _requestJson(
        'POST',
        '/api/v1/conversations',
        body: {
          'title': input.title,
          'other_participant_name': input.participantName,
        },
        expectedStatuses: const {HttpStatus.created},
      ),
      code: 'conversation_create_invalid',
    );
    final conversationId = _requiredString(created, 'id');

    try {
      final confirmed = _object(
        await _requestJson(
          'POST',
          '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/confirm',
          body: _confirmationPayload(input),
        ),
        code: 'conversation_confirm_invalid',
      );
      final events = _object(
        await _requestJson(
          'PUT',
          '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/events',
          body: ConversationEventSequenceDto(
            events: [
              for (final event in input.events)
                ConversationEventDto(event: event),
            ],
            relationships: [
              for (final relationship in input.relationships)
                ConversationEventRelationshipDto(relationship: relationship),
            ],
          ).toJson(),
        ),
        code: 'conversation_events_invalid',
      );
      return _detailToDto(confirmed, events);
    } on Object {
      await _bestEffortDelete(conversationId);
      rethrow;
    }
  }

  @override
  Future<SavedConversationDto?> getConversation(String conversationId) async {
    final encoded = Uri.encodeComponent(conversationId);
    final detailResponse = await _request(
      'GET',
      '/api/v1/conversations/$encoded',
      expectedStatuses: const {HttpStatus.ok, HttpStatus.notFound},
    );
    if (detailResponse.statusCode == HttpStatus.notFound) return null;
    final detail = _object(
      _decode(detailResponse.bytes),
      code: 'conversation_detail_invalid',
    );
    final events = _object(
      await _requestJson('GET', '/api/v1/conversations/$encoded/events'),
      code: 'conversation_events_invalid',
    );
    return _detailToDto(detail, events);
  }

  Map<String, Object?> _confirmationPayload(SavedConversationInput input) {
    return {
      'title': input.title,
      'source_type': input.sourceType,
      'readiness_score': input.readinessScore,
      'sources': [
        for (final source in input.sources)
          {
            'source_type': input.sourceType,
            'source_index': source.index,
            'mime_type': source.mimeType,
            'byte_size': source.byteSize,
            'storage_status': source.storageStatus,
          },
      ],
      'messages': [
        for (final message in input.messages)
          {
            'speaker': message.speaker,
            'text': message.text,
            'timestamp': message.timestamp?.toUtc().toIso8601String(),
            'visible_timestamp_text': message.visibleTimestampText,
            'timestamp_estimated': message.timestampEstimated,
            'ocr_confidence': message.ocrConfidence,
            'source_screenshot_index': message.sourceScreenshotIndex,
            'review_status': 'edited',
          },
      ],
      'extraction_metadata': switch (input.extractionMetadata) {
        final metadata? => {
          'provider': metadata.provider,
          'provider_version': metadata.providerVersion,
          'extraction_version': metadata.extractionVersion,
          'preprocessing_version': metadata.preprocessingVersion,
          'confidence_available': metadata.confidenceAvailable,
        },
        null => null,
      },
    };
  }

  SavedConversationDto _detailToDto(
    Map<String, Object?> detail,
    Map<String, Object?> eventPayload,
  ) {
    final eventSequence = ConversationEventSequenceDto.fromJson(eventPayload);
    final participants = _objectList(detail['participants']);
    final other = participants.firstWhere(
      (participant) => participant['role'] == 'other',
      orElse: () => const <String, Object?>{},
    );
    final sourceType = _requiredString(detail, 'source_type');
    return SavedConversationDto(
      id: _requiredString(detail, 'id'),
      title: _requiredString(detail, 'title'),
      participantName: other['display_name'] as String? ?? 'Other person',
      sourceType: sourceType,
      readinessScore: detail['readiness_score'] as int? ?? 0,
      messages: [
        for (final message in _objectList(detail['messages']))
          NormalizedConversationMessage(
            id: _requiredString(message, 'id'),
            speaker: _requiredString(message, 'speaker'),
            text: _requiredString(message, 'body'),
            timestamp: _dateTime(message['sent_at']),
            timestampEstimated:
                message['timestamp_estimated'] as bool? ?? false,
            ocrConfidence: _number(message['ocr_confidence']),
            sourceScreenshotIndex: message['source_screenshot_index'] as int?,
            visibleTimestampText: message['visible_timestamp_text'] as String?,
          ),
      ],
      sources: [
        for (final source in _objectList(detail['sources']))
          SavedConversationSource(
            index: source['source_index'] as int? ?? 0,
            mimeType: source['mime_type'] as String?,
            byteSize: source['byte_size'] as int?,
            storageStatus: _requiredString(source, 'storage_status'),
          ),
      ],
      updatedAt: _requiredDateTime(detail, 'updated_at'),
      extractionMetadata: _extractionMetadata(detail['extraction_metadata']),
      events: [for (final item in eventSequence.events) item.event],
      relationships: [
        for (final item in eventSequence.relationships) item.relationship,
      ],
    );
  }

  void _validateReviewedInput(SavedConversationInput input) {
    if (!const {'paste', 'screenshot'}.contains(input.sourceType) ||
        input.messages.length < 2 ||
        input.events.isEmpty ||
        input.events.any((event) => event.requiresReview) ||
        input.messages.any(
          (message) =>
              !const {'user', 'other'}.contains(message.speaker) ||
              message.text.trim().isEmpty,
        )) {
      throw const ConversationApiException(code: 'review_incomplete');
    }
  }

  Future<Object?> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? body,
    Set<int> expectedStatuses = const {HttpStatus.ok},
  }) async {
    final response = await _request(
      method,
      path,
      body: body,
      expectedStatuses: expectedStatuses,
    );
    return _decode(response.bytes);
  }

  Future<_BoundedResponse> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    required Set<int> expectedStatuses,
  }) async {
    final client = _clientFactory();
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null || accessToken.isEmpty) {
        throw const ConversationApiException(code: 'authentication_required');
      }
      final request = await client.openUrl(method, baseUri.resolve(path));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/json')
          ..contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = await _readBounded(response);
      if (!expectedStatuses.contains(response.statusCode)) {
        throw ConversationApiException(
          code: 'request_failed',
          statusCode: response.statusCode,
        );
      }
      return _BoundedResponse(response.statusCode, bytes);
    } on ConversationApiException {
      rethrow;
    } on TimeoutException {
      throw const ConversationApiException(code: 'request_timed_out');
    } on FormatException {
      throw const ConversationApiException(code: 'response_invalid');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _readBounded(HttpClientResponse response) async {
    if (response.contentLength > _maximumResponseBytes) {
      throw const ConversationApiException(code: 'response_too_large');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maximumResponseBytes) {
        throw const ConversationApiException(code: 'response_too_large');
      }
    }
    return bytes;
  }

  Future<void> _bestEffortDelete(String conversationId) async {
    try {
      await deleteConversation(conversationId);
    } on Object {
      // The original safe failure remains authoritative. The server's privacy
      // deletion surface can remove an orphan if this cleanup is interrupted.
    }
  }
}

final class _BoundedResponse {
  const _BoundedResponse(this.statusCode, this.bytes);

  final int statusCode;
  final List<int> bytes;
}

Object? _decode(List<int> bytes) {
  if (bytes.isEmpty) return null;
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ConversationApiException(code: 'response_invalid');
  }
}

Map<String, Object?> _object(Object? value, {required String code}) {
  if (value is! Map<String, Object?>) {
    throw ConversationApiException(code: code);
  }
  return value;
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List<Object?>) {
    throw const ConversationApiException(code: 'response_invalid');
  }
  return value
      .map((item) => _object(item, code: 'response_invalid'))
      .toList(growable: false);
}

String _requiredString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) {
    throw const ConversationApiException(code: 'response_invalid');
  }
  return field;
}

DateTime _requiredDateTime(Map<String, Object?> value, String key) {
  final parsed = _dateTime(value[key]);
  if (parsed == null) {
    throw const ConversationApiException(code: 'response_invalid');
  }
  return parsed;
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

double? _number(Object? value) => value is num ? value.toDouble() : null;

SavedExtractionMetadata? _extractionMetadata(Object? value) {
  if (value == null) return null;
  final metadata = _object(value, code: 'extraction_metadata_invalid');
  final confidenceAvailable = metadata['confidence_available'];
  if (confidenceAvailable is! bool) {
    throw const ConversationApiException(code: 'extraction_metadata_invalid');
  }
  return SavedExtractionMetadata(
    provider: _requiredString(metadata, 'provider'),
    providerVersion: _requiredString(metadata, 'provider_version'),
    extractionVersion: _requiredString(metadata, 'extraction_version'),
    preprocessingVersion: _requiredString(metadata, 'preprocessing_version'),
    confidenceAvailable: confidenceAvailable,
  );
}
