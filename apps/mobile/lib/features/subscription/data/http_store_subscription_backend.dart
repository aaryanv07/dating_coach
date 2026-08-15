import 'dart:convert';
import 'dart:io';

import 'package:convo_coach/features/subscription/domain/store_subscription.dart';

const _maximumStoreResponseBytes = 64 * 1024;

class HttpStoreSubscriptionBackend implements StoreSubscriptionBackend {
  HttpStoreSubscriptionBackend({
    required this.baseUri,
    required this.accessTokenProvider,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final Uri baseUri;
  final Future<String?> Function() accessTokenProvider;
  final HttpClient Function() _clientFactory;

  @override
  Future<StorePurchaseContext> purchaseContext() async {
    final payload = await _request('/api/v1/subscription/purchase-context');
    if (payload.keys.toSet().difference(const {
          'schema_version',
          'account_reference',
          'purchase_enabled',
        }).isNotEmpty ||
        payload['schema_version'] != 'store-purchase-context.v1' ||
        payload['account_reference'] is! String ||
        payload['purchase_enabled'] is! bool) {
      throw const StoreSubscriptionException('purchase_context_invalid');
    }
    return StorePurchaseContext(
      accountReference: payload['account_reference']! as String,
      purchaseEnabled: payload['purchase_enabled']! as bool,
    );
  }

  @override
  Future<VerifiedEntitlement> verify({
    required StoreBillingPlatform platform,
    required String productId,
    required String verificationData,
  }) async {
    final payload = await _request(
      '/api/v1/subscription/verify',
      body: {
        'schema_version': 'store-purchase-verification-request.v1',
        'storefront': platform == StoreBillingPlatform.apple
            ? 'apple'
            : 'google',
        'product_id': productId,
        'verification_data': verificationData,
      },
    );
    if (payload['schema_version'] !=
            'store-purchase-verification-response.v1' ||
        payload['plan_code'] != 'plus' ||
        payload['plan_status'] is! String ||
        payload['current_period_end'] is! String) {
      throw const StoreSubscriptionException('store_verification_invalid');
    }
    final periodEnd = DateTime.tryParse(
      payload['current_period_end']! as String,
    )?.toUtc();
    final planStatus = payload['plan_status']! as String;
    if (periodEnd == null ||
        !const {'active', 'grace', 'expired', 'revoked'}.contains(planStatus)) {
      throw const StoreSubscriptionException('store_verification_invalid');
    }
    return VerifiedEntitlement(
      planStatus: planStatus,
      currentPeriodEnd: periodEnd,
    );
  }

  Future<Map<String, Object?>> _request(
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const StoreSubscriptionException('authentication_required');
    }
    final client = _clientFactory();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = body == null
          ? await client.getUrl(baseUri.resolve(path))
          : await client.postUrl(baseUri.resolve(path));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.cacheControlHeader, 'no-store');
      if (body != null) {
        final encoded = utf8.encode(jsonEncode(body));
        request.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/json')
          ..contentLength = encoded.length;
        request.add(encoded);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw const StoreSubscriptionException('store_request_failed');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maximumStoreResponseBytes) {
          throw const StoreSubscriptionException('store_response_too_large');
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const StoreSubscriptionException('store_response_invalid');
      }
      return decoded;
    } on StoreSubscriptionException {
      rethrow;
    } on Object {
      throw const StoreSubscriptionException('store_request_unavailable');
    } finally {
      client.close(force: true);
    }
  }
}
