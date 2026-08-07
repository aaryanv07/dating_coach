import 'dart:async';

import 'package:convo_coach/features/subscription/application/store_subscription_controller.dart';
import 'package:convo_coach/features/subscription/domain/store_subscription.dart';
import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements StoreBillingGateway {
  final StreamController<List<StorePurchaseUpdate>> updates =
      StreamController.broadcast();
  bool available = true;
  int completionCount = 0;
  String? purchasedProduct;
  String? purchaseAccount;

  @override
  Stream<List<StorePurchaseUpdate>> get purchaseUpdates => updates.stream;

  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {
    completionCount += 1;
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> purchase({
    required String productId,
    required String accountReference,
  }) async {
    purchasedProduct = productId;
    purchaseAccount = accountReference;
  }

  @override
  Future<List<StoreProductOffer>> queryProducts(
    Map<String, BillingPeriod> products,
  ) async => products.entries
      .map(
        (entry) => StoreProductOffer(
          productId: entry.key,
          billingPeriod: entry.value,
          localizedPrice: entry.value == BillingPeriod.monthly
              ? '₹999'
              : '₹8,999',
        ),
      )
      .toList();

  @override
  Future<void> restore({required String accountReference}) async {}

  Future<void> close() => updates.close();
}

class _FakeBackend implements StoreSubscriptionBackend {
  bool purchaseEnabled = true;
  bool rejectVerification = false;

  @override
  Future<StorePurchaseContext> purchaseContext() async => StorePurchaseContext(
    accountReference: '11111111-1111-4111-8111-111111111111',
    purchaseEnabled: purchaseEnabled,
  );

  @override
  Future<VerifiedEntitlement> verify({
    required StoreBillingPlatform platform,
    required String productId,
    required String verificationData,
  }) async {
    if (rejectVerification) {
      throw const StoreSubscriptionException('verification_rejected');
    }
    return VerifiedEntitlement(
      planStatus: 'active',
      currentPeriodEnd: DateTime.utc(2027),
    );
  }
}

const _products = {
  'com.convocoach.plus.monthly.ios': BillingPeriod.monthly,
  'com.convocoach.plus.yearly.ios': BillingPeriod.yearly,
};

StorePurchaseUpdate verifiedUpdate() => const StorePurchaseUpdate(
  completionReference: 'completion-1',
  productId: 'com.convocoach.plus.monthly.ios',
  lifecycle: StorePurchaseLifecycle.purchased,
  verificationData: 'store-signed-evidence',
  pendingCompletion: true,
);

void main() {
  test('purchase starts only after context and products are ready', () async {
    final store = _FakeStore();
    addTearDown(store.close);
    final controller = StoreSubscriptionController(
      platform: StoreBillingPlatform.apple,
      productIds: _products,
      store: store,
      backend: _FakeBackend(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.purchase(BillingPeriod.monthly);

    expect(controller.state.phase, StoreSubscriptionPhase.purchasing);
    expect(store.purchasedProduct, 'com.convocoach.plus.monthly.ios');
    expect(store.purchaseAccount, '11111111-1111-4111-8111-111111111111');
  });

  test(
    'transaction completes only after server verification succeeds',
    () async {
      final store = _FakeStore();
      addTearDown(store.close);
      final controller = StoreSubscriptionController(
        platform: StoreBillingPlatform.apple,
        productIds: _products,
        store: store,
        backend: _FakeBackend(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      store.updates.add([verifiedUpdate()]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.phase, StoreSubscriptionPhase.active);
      expect(store.completionCount, 1);
    },
  );

  test('failed server verification never completes the transaction', () async {
    final store = _FakeStore();
    addTearDown(store.close);
    final backend = _FakeBackend()..rejectVerification = true;
    final controller = StoreSubscriptionController(
      platform: StoreBillingPlatform.apple,
      productIds: _products,
      store: store,
      backend: backend,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    store.updates.add([verifiedUpdate()]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.phase, StoreSubscriptionPhase.error);
    expect(store.completionCount, 0);
  });

  test('disabled server context prevents store purchase actions', () async {
    final store = _FakeStore();
    addTearDown(store.close);
    final backend = _FakeBackend()..purchaseEnabled = false;
    final controller = StoreSubscriptionController(
      platform: StoreBillingPlatform.google,
      productIds: _products,
      store: store,
      backend: backend,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.state.phase, StoreSubscriptionPhase.disabled);
    expect(controller.state.canPurchase, isFalse);
  });
}
