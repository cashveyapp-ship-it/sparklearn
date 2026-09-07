import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  static const String monthlyId = 'sparklearn_premium_monthly';
  static const String yearlyId = 'sparklearn_premium_yearly';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> products = [];
  bool available = false;

  Future<void> initialize() async {
    available = await _iap.isAvailable();

    if (!available) return;

    const ids = {
      monthlyId,
      yearlyId,
    };

    final response = await _iap.queryProductDetails(ids);

    products = response.productDetails;

    _subscription ??= _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (_) {},
    );
  }

  ProductDetails? get monthly {
    for (final product in products) {
      if (product.id == monthlyId) return product;
    }
    return null;
  }

  ProductDetails? get yearly {
    for (final product in products) {
      if (product.id == yearlyId) return product;
    }
    return null;
  }

  Future<void> buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);

    await _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchases(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final callable = _functions.httpsCallable('verifyPremiumPurchase');

        await callable.call({
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'source': purchase.verificationData.source,
          'verificationData': purchase.verificationData.serverVerificationData,
        });
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

