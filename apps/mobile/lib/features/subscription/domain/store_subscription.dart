import 'dart:async';

import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';

enum StoreBillingPlatform { apple, google }

enum StorePurchaseLifecycle { pending, purchased, restored, canceled, failed }

class StoreProductOffer {
  const StoreProductOffer({
    required this.productId,
    required this.billingPeriod,
    required this.localizedPrice,
  });

  final String productId;
  final BillingPeriod billingPeriod;
  final String localizedPrice;
}

class StorePurchaseUpdate {
  const StorePurchaseUpdate({
    required this.completionReference,
    required this.productId,
    required this.lifecycle,
    required this.verificationData,
    required this.pendingCompletion,
    this.errorCode,
  });

  final String completionReference;
  final String productId;
  final StorePurchaseLifecycle lifecycle;
  final String verificationData;
  final bool pendingCompletion;
  final String? errorCode;
}

class StorePurchaseContext {
  const StorePurchaseContext({
    required this.accountReference,
    required this.purchaseEnabled,
  });

  final String accountReference;
  final bool purchaseEnabled;
}

class VerifiedEntitlement {
  const VerifiedEntitlement({
    required this.planStatus,
    required this.currentPeriodEnd,
  });

  final String planStatus;
  final DateTime currentPeriodEnd;
}

abstract interface class StoreBillingGateway {
  Stream<List<StorePurchaseUpdate>> get purchaseUpdates;

  Future<bool> isAvailable();

  Future<List<StoreProductOffer>> queryProducts(
    Map<String, BillingPeriod> products,
  );

  Future<void> purchase({
    required String productId,
    required String accountReference,
  });

  Future<void> restore({required String accountReference});

  Future<void> complete(StorePurchaseUpdate purchase);
}

abstract interface class StoreSubscriptionBackend {
  Future<StorePurchaseContext> purchaseContext();

  Future<VerifiedEntitlement> verify({
    required StoreBillingPlatform platform,
    required String productId,
    required String verificationData,
  });
}

class StoreSubscriptionException implements Exception {
  const StoreSubscriptionException(this.code);

  final String code;

  @override
  String toString() => 'StoreSubscriptionException($code)';
}
