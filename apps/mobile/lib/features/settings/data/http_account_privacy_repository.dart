import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/settings/domain/account_privacy_repository.dart';

final class AccountPrivacyException implements Exception {
  const AccountPrivacyException(this.code);

  final String code;

  @override
  String toString() => 'AccountPrivacyException($code)';
}

final class HttpAccountPrivacyRepository implements AccountPrivacyRepository {
  HttpAccountPrivacyRepository({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Uri baseUri;
  final Future<String?> Function() accessTokenProvider;
  final HttpClient Function() _clientFactory;

  static const _maximumExportBytes = 20 * 1024 * 1024;

  @override
  Future<String> exportAccountData() async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const AccountPrivacyException('authentication_required');
    }
    final client = _clientFactory();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .getUrl(baseUri.resolve('/api/v1/privacy/export'))
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const AccountPrivacyException('account_export_failed');
      }
      if (response.contentLength > _maximumExportBytes) {
        await response.drain<void>();
        throw const AccountPrivacyException('account_export_too_large');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumExportBytes) {
          throw const AccountPrivacyException('account_export_too_large');
        }
      }
      return utf8.decode(bytes);
    } on AccountPrivacyException {
      rethrow;
    } on Object {
      throw const AccountPrivacyException('account_export_unavailable');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> requestAccountDeletion() async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const AccountPrivacyException('authentication_required');
    }
    final client = _clientFactory();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .postUrl(baseUri.resolve('/api/v1/privacy/delete-account'))
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      await response.drain<void>();
      if (response.statusCode != HttpStatus.accepted) {
        throw const AccountPrivacyException('account_deletion_failed');
      }
    } on AccountPrivacyException {
      rethrow;
    } on Object {
      throw const AccountPrivacyException('account_deletion_unavailable');
    } finally {
      client.close(force: true);
    }
  }
}
