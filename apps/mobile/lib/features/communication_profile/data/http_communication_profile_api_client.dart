import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/communication_profile/data/communication_profile_api_client.dart';
import 'package:convo_coach/features/communication_profile/data/communication_profile_dto.dart';

const _maximumJsonBytes = 256 * 1024;
const _maximumPhotoBytes = 900 * 1024;

final class CommunicationProfileApiException implements Exception {
  const CommunicationProfileApiException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => 'CommunicationProfileApiException($code)';
}

final class HttpCommunicationProfileApiClient
    implements CommunicationProfileApiClient {
  HttpCommunicationProfileApiClient({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Uri baseUri;
  final Future<String?> Function() accessTokenProvider;
  final HttpClient Function() _clientFactory;

  @override
  Future<CommunicationProfileDto> fetchProfile() async {
    final response = await _request('GET', '/api/v1/communication-profile');
    return CommunicationProfileDto.fromJson(_decodeObject(response.bytes));
  }

  @override
  Future<CommunicationProfileDto> updateProfile(
    CommunicationProfileDto profile,
  ) async {
    final response = await _request(
      'PATCH',
      '/api/v1/communication-profile',
      jsonBody: profile.toJson(),
    );
    return CommunicationProfileDto.fromJson(_decodeObject(response.bytes));
  }

  @override
  Future<List<int>?> fetchProfilePhoto() async {
    final response = await _request(
      'GET',
      '/api/v1/communication-profile/photo',
      expectedStatuses: const {HttpStatus.ok, HttpStatus.notFound},
      maximumResponseBytes: _maximumPhotoBytes,
    );
    return response.statusCode == HttpStatus.notFound ? null : response.bytes;
  }

  @override
  Future<void> updateProfilePhoto(List<int> bytes, String contentType) async {
    if (bytes.isEmpty || bytes.length > _maximumPhotoBytes) {
      throw const CommunicationProfileApiException('photo_size_invalid');
    }
    await _request(
      'PUT',
      '/api/v1/communication-profile/photo',
      rawBody: bytes,
      contentType: contentType,
      expectedStatuses: const {HttpStatus.noContent},
    );
  }

  @override
  Future<void> deleteProfilePhoto() async {
    await _request(
      'DELETE',
      '/api/v1/communication-profile/photo',
      expectedStatuses: const {HttpStatus.noContent},
    );
  }

  Future<_ProfileResponse> _request(
    String method,
    String path, {
    Map<String, Object?>? jsonBody,
    List<int>? rawBody,
    String? contentType,
    Set<int> expectedStatuses = const {HttpStatus.ok},
    int maximumResponseBytes = _maximumJsonBytes,
  }) async {
    final client = _clientFactory();
    try {
      final token = await accessTokenProvider();
      if (token == null || token.isEmpty) {
        throw const CommunicationProfileApiException('authentication_required');
      }
      final request = await client.openUrl(method, baseUri.resolve(path));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      final body = jsonBody == null
          ? rawBody
          : utf8.encode(jsonEncode(jsonBody));
      if (body != null) {
        request.headers
          ..set(
            HttpHeaders.contentTypeHeader,
            jsonBody == null ? contentType! : 'application/json',
          )
          ..contentLength = body.length;
        request.add(body);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = await _readBounded(response, maximumResponseBytes);
      if (!expectedStatuses.contains(response.statusCode)) {
        throw CommunicationProfileApiException(
          'request_failed',
          statusCode: response.statusCode,
        );
      }
      return _ProfileResponse(response.statusCode, bytes);
    } on CommunicationProfileApiException {
      rethrow;
    } on TimeoutException {
      throw const CommunicationProfileApiException('request_timed_out');
    } on FormatException {
      throw const CommunicationProfileApiException('response_invalid');
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _readBounded(
    HttpClientResponse response,
    int maximum,
  ) async {
    if (response.contentLength > maximum) {
      throw const CommunicationProfileApiException('response_too_large');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > maximum) {
        throw const CommunicationProfileApiException('response_too_large');
      }
    }
    return bytes;
  }

  Map<String, Object?> _decodeObject(List<int> bytes) {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, Object?>) {
      throw const CommunicationProfileApiException('response_invalid');
    }
    return value;
  }
}

final class _ProfileResponse {
  const _ProfileResponse(this.statusCode, this.bytes);

  final int statusCode;
  final List<int> bytes;
}
