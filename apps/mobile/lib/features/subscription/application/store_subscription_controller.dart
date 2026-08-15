import 'dart:async';

import 'package:convo_coach/features/subscription/domain/store_subscription.dart';
import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';
import 'package:flutter/foundation.dart';

enum StoreSubscriptionPhase {
  disabled,
  loading,
  ready,
  purchasing,
  restoring,
  active,
  error,
}

class StoreSubscriptionState {
  const StoreSubscriptionState({
    required this.phase,
    this.offers = const {},
    this.message,
  });

  final StoreSubscriptionPhase phase;
  final Map<BillingPeriod, StoreProductOffer> offers;
  final String? message;

  bool get canPurchase =>
      phase == StoreSubscriptionPhase.ready && offers.isNotEmpty;
}

class StoreSubscriptionController extends ChangeNotifier {
  StoreSubscriptionController({
    required this.platform,
    required this.productIds,
    required this.store,
    required this.backend,
  });

  final StoreBillingPlatform platform;
  final Map<String, BillingPeriod> productIds;
  final StoreBillingGateway store;
  final StoreSubscriptionBackend backend;
  StreamSubscription<List<StorePurchaseUpdate>>? _purchaseSubscription;
  StorePurchaseContext? _context;
  StoreSubscriptionState _state = const StoreSubscriptionState(
    phase: StoreSubscriptionPhase.loading,
  );

  StoreSubscriptionState get state => _state;

  Future<void> initialize() async {
    _setState(
      const StoreSubscriptionState(phase: StoreSubscriptionPhase.loading),
    );
    _purchaseSubscription ??= store.purchaseUpdates.listen(
      _handlePurchases,
      onError: (_) => _fail('Purchase updates are temporarily unavailable.'),
    );
    try {
      _context = await backend.purchaseContext();
      if (!_context!.purchaseEnabled || !await store.isAvailable()) {
        _setState(
          const StoreSubscriptionState(
            phase: StoreSubscriptionPhase.disabled,
            message: 'Purchases are not available on this device yet.',
          ),
        );
        return;
      }
      final offers = await store.queryProducts(productIds);
      if (offers.length != productIds.length) {
        throw const StoreSubscriptionException('store_products_incomplete');
      }
      _setState(
        StoreSubscriptionState(
          phase: StoreSubscriptionPhase.ready,
          offers: {for (final offer in offers) offer.billingPeriod: offer},
        ),
      );
    } on Object {
      _fail('Plans could not be loaded. Please try again.');
    }
  }

  Future<void> purchase(BillingPeriod billingPeriod) async {
    final offer = _state.offers[billingPeriod];
    final context = _context;
    if (!_state.canPurchase || offer == null || context == null) return;
    _setState(
      StoreSubscriptionState(
        phase: StoreSubscriptionPhase.purchasing,
        offers: _state.offers,
        message: 'Complete the purchase securely with the store.',
      ),
    );
    try {
      await store.purchase(
        productId: offer.productId,
        accountReference: context.accountReference,
      );
    } on Object {
      _fail('The store could not start this purchase.');
    }
  }

  Future<void> restore() async {
    final context = _context;
    if (context == null || _state.phase == StoreSubscriptionPhase.loading) {
      return;
    }
    _setState(
      StoreSubscriptionState(
        phase: StoreSubscriptionPhase.restoring,
        offers: _state.offers,
        message: 'Checking your store purchases…',
      ),
    );
    try {
      await store.restore(accountReference: context.accountReference);
    } on Object {
      _fail('Purchases could not be restored.');
    }
  }

  Future<void> _handlePurchases(List<StorePurchaseUpdate> updates) async {
    for (final purchase in updates) {
      if (!productIds.containsKey(purchase.productId)) continue;
      switch (purchase.lifecycle) {
        case StorePurchaseLifecycle.pending:
          _setState(
            StoreSubscriptionState(
              phase: StoreSubscriptionPhase.purchasing,
              offers: _state.offers,
              message: 'The store is processing your purchase.',
            ),
          );
        case StorePurchaseLifecycle.canceled:
          _setState(
            StoreSubscriptionState(
              phase: StoreSubscriptionPhase.ready,
              offers: _state.offers,
              message: 'Purchase canceled. No entitlement was changed.',
            ),
          );
        case StorePurchaseLifecycle.failed:
          _fail('The purchase did not complete. You were not upgraded.');
        case StorePurchaseLifecycle.purchased:
        case StorePurchaseLifecycle.restored:
          await _verifyAndComplete(purchase);
      }
    }
  }

  Future<void> _verifyAndComplete(StorePurchaseUpdate purchase) async {
    try {
      final entitlement = await backend.verify(
        platform: platform,
        productId: purchase.productId,
        verificationData: purchase.verificationData,
      );
      if (!const {'active', 'grace'}.contains(entitlement.planStatus)) {
        throw const StoreSubscriptionException('entitlement_not_active');
      }
      if (purchase.pendingCompletion) {
        await store.complete(purchase);
      }
      _setState(
        StoreSubscriptionState(
          phase: StoreSubscriptionPhase.active,
          offers: _state.offers,
          message: entitlement.planStatus == 'grace'
              ? 'Plus restored in billing grace period.'
              : 'Plus is active. Your expanded allowances are ready.',
        ),
      );
    } on Object {
      // Never finish a transaction or grant client access after failed server verification.
      _fail('The store receipt could not be verified. No upgrade was granted.');
    }
  }

  void _fail(String message) {
    _setState(
      StoreSubscriptionState(
        phase: StoreSubscriptionPhase.error,
        offers: _state.offers,
        message: message,
      ),
    );
  }

  void _setState(StoreSubscriptionState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
