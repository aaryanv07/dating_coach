import 'package:convo_coach/core/config/app_config.dart';
import 'package:convo_coach/features/authentication/application/authentication_providers.dart';
import 'package:convo_coach/features/subscription/data/http_store_subscription_backend.dart';
import 'package:convo_coach/features/subscription/data/in_app_purchase_gateway.dart';
import 'package:convo_coach/features/subscription/domain/store_subscription.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storeBillingGatewayProvider = Provider<StoreBillingGateway>(
  (ref) => InAppPurchaseGateway(),
);

final storeSubscriptionBackendProvider = Provider<StoreSubscriptionBackend>((
  ref,
) {
  final baseUri = Uri.parse(AppConfig.apiBaseUrl);
  return HttpStoreSubscriptionBackend(
    baseUri: baseUri,
    accessTokenProvider: ref
        .watch(authenticationAccessTokenProvider)
        .accessToken,
  );
});
