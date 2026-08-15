import 'dart:async';

import 'package:convo_coach/features/subscription/domain/store_subscription.dart';
import 'package:convo_coach/features/subscription/domain/subscription_plan.dart';
import 'package:crypto/crypto.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseGateway implements StoreBillingGateway {
  InAppPurchaseGateway({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  final Map<String, ProductDetails> _products = {};
  final Map<String, PurchaseDetails> _pendingCompletion = {};

  @override
  Stream<List<StorePurchaseUpdate>> get purchaseUpdates =>
      _store.purchaseStream.map((purchases) {
        return purchases
            .map((purchase) {
              final reference = _completionReference(purchase);
              if (purchase.pendingCompletePurchase) {
                _pendingCompletion[reference] = purchase;
              }
              return StorePurchaseUpdate(
                completionReference: reference,
                productId: purchase.productID,
                lifecycle: switch (purchase.status) {
                  PurchaseStatus.pending => StorePurchaseLifecycle.pending,
                  PurchaseStatus.purchased => StorePurchaseLifecycle.purchased,
                  PurchaseStatus.restored => StorePurchaseLifecycle.restored,
                  PurchaseStatus.canceled => StorePurchaseLifecycle.canceled,
                  PurchaseStatus.error => StorePurchaseLifecycle.failed,
                },
                verificationData:
                    purchase.verificationData.serverVerificationData,
                pendingCompletion: purchase.pendingCompletePurchase,
                errorCode: purchase.error?.code,
              );
            })
            .toList(growable: false);
      });

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<List<StoreProductOffer>> queryProducts(
    Map<String, BillingPeriod> products,
  ) async {
    final response = await _store.queryProductDetails(products.keys.toSet());
    if (response.error != null || response.notFoundIDs.isNotEmpty) {
      throw const StoreSubscriptionException('store_products_unavailable');
    }
    _products
      ..clear()
      ..addEntries(
        response.productDetails.map((product) => MapEntry(product.id, product)),
      );
    return response.productDetails
        .map(
          (product) => StoreProductOffer(
            productId: product.id,
            billingPeriod: products[product.id]!,
            localizedPrice: product.price,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> purchase({
    required String productId,
    required String accountReference,
  }) async {
    final product = _products[productId];
    if (product == null) {
      throw const StoreSubscriptionException('store_product_missing');
    }
    final started = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: accountReference,
      ),
    );
    if (!started) {
      throw const StoreSubscriptionException('store_purchase_not_started');
    }
  }

  @override
  Future<void> restore({required String accountReference}) =>
      _store.restorePurchases(applicationUserName: accountReference);

  @override
  Future<void> complete(StorePurchaseUpdate purchase) async {
    final details = _pendingCompletion.remove(purchase.completionReference);
    if (details == null) {
      throw const StoreSubscriptionException('store_completion_missing');
    }
    await _store.completePurchase(details);
  }

  String _completionReference(PurchaseDetails purchase) {
    final material = [
      purchase.verificationData.source,
      purchase.productID,
      purchase.purchaseID ?? '',
      purchase.verificationData.serverVerificationData,
    ].join('\u0000');
    return sha256.convert(material.codeUnits).toString();
  }
}
