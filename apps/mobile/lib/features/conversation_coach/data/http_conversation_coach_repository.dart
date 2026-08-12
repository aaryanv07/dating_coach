import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convo_coach/features/conversation_coach/data/conversation_coach_transport.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_preview.dart';
import 'package:convo_coach/features/conversation_coach/domain/conversation_coach_repository.dart';

const _maximumResponseBytes = 262144;

class HttpConversationCoachRepository
    implements
        ConversationCoachRepository,
        ExternalProcessingConsentRepository,
        AIOutputReportingRepository {
  HttpConversationCoachRepository({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Uri baseUri;
  final Future<String?> Function() accessTokenProvider;
  final HttpClient Function() _clientFactory;
  final Map<String, String> _idempotencyKeys = {};

  @override
  Future<bool> reportOutput({
    required String conversationId,
    required String responseId,
    required CoachOutputReportCategory category,
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) return false;
    final client = _clientFactory();
    HttpClientRequest? request;
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null || accessToken.isEmpty) {
        throw const ConversationCoachTransportException();
      }
      request = await client.postUrl(
        baseUri.resolve(
          '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/coach-reports',
        ),
      );
      final body = utf8.encode(
        jsonEncode({
          'schema_version': 'coach-output-report-request.v1',
          'response_id': responseId,
          'category': category.wireValue,
        }),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..contentLength = body.length;
      request.add(body);
      cancellationToken.bind(request.abort);
      final response = await request.close();
      if (cancellationToken.isCancelled) return false;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumResponseBytes) {
          request.abort();
          throw const ConversationCoachTransportException();
        }
      }
      if (response.statusCode != HttpStatus.created) return false;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> ||
          decoded.keys.toSet().difference({
            'schema_version',
            'report_id',
            'status',
            'created_at',
          }).isNotEmpty ||
          decoded.length != 4 ||
          decoded['schema_version'] != 'coach-output-report-receipt.v1' ||
          decoded['status'] != 'received' ||
          decoded['report_id'] is! String ||
          decoded['created_at'] is! String) {
        throw const ConversationCoachTransportException();
      }
      return true;
    } on FormatException {
      throw const ConversationCoachTransportException();
    } finally {
      cancellationToken.clear();
      client.close(force: true);
    }
  }

  @override
  Future<bool> grantExternalProcessingConsent({
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) return false;
    final client = _clientFactory();
    HttpClientRequest? request;
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null || accessToken.isEmpty) {
        throw const ConversationCoachTransportException();
      }
      request = await client.postUrl(baseUri.resolve('/api/v1/consents'));
      final body = utf8.encode(
        jsonEncode({
          'consent_type': 'external_ai_processing',
          'granted': true,
          'policy_version': 'external-ai-processing-v3',
        }),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..contentLength = body.length;
      request.add(body);
      cancellationToken.bind(request.abort);
      final response = await request.close();
      if (cancellationToken.isCancelled) return false;
      var receivedBytes = 0;
      await for (final chunk in response) {
        receivedBytes += chunk.length;
        if (receivedBytes > _maximumResponseBytes) {
          request.abort();
          throw const ConversationCoachTransportException();
        }
      }
      return response.statusCode == HttpStatus.created;
    } finally {
      cancellationToken.clear();
      client.close(force: true);
    }
  }

  @override
  Future<ConversationCoachRepositoryResult> fetchPreview(
    String conversationId, {
    required ConversationCoachCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCancelled) {
      return _cancelled();
    }
    final client = _clientFactory();
    HttpClientRequest? request;
    try {
      final accessToken = await accessTokenProvider();
      if (accessToken == null || accessToken.isEmpty) {
        throw const ConversationCoachTransportException();
      }
      final endpoint = baseUri.resolve(
        '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/coach-preview',
      );
      request = await client.postUrl(endpoint);
      final idempotencyKey = _idempotencyKeys.putIfAbsent(
        conversationId,
        _newIdempotencyKey,
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set('Idempotency-Key', idempotencyKey)
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..contentLength = 0;
      cancellationToken.bind(request.abort);
      final response = await request.close();
      if (cancellationToken.isCancelled) return _cancelled();
      if (response.contentLength > _maximumResponseBytes) {
        throw const ConversationCoachTransportException();
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumResponseBytes) {
          request.abort();
          throw const ConversationCoachTransportException();
        }
      }
      final result = parseConversationCoachTransport(utf8.decode(bytes));
      if (result is ConversationCoachRepositorySuccess) {
        _idempotencyKeys.remove(conversationId);
      }
      return result;
    } on ConversationCoachTransportException {
      rethrow;
    } on SocketException {
      rethrow;
    } on HttpException {
      if (cancellationToken.isCancelled) return _cancelled();
      rethrow;
    } finally {
      cancellationToken.clear();
      client.close(force: true);
    }
  }

  ConversationCoachRepositoryResult _cancelled() {
    return const ConversationCoachRepositoryFailure(
      ConversationCoachFailure(
        code: ConversationCoachErrorCode.cancelled,
        localizationKey: 'coaching.error.cancelled',
        retryable: true,
        retryGuidanceLocalizationKey: 'coaching.error.cancelled.retry',
        correlationId: 'local-cancelled',
      ),
    );
  }
}

String _newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
