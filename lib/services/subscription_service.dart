import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (kIsWeb) {
      available = true;
      return;
    }

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
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );
  }

  ProductDetails? get monthly {
    for (final product in products) {
      if (product.id == monthlyId) {
        return product;
      }
    }

    return null;
  }

  ProductDetails? get yearly {
    for (final product in products) {
      if (product.id == yearlyId) {
        return product;
      }
    }

    return null;
  }

  Future<void> buy(ProductDetails product) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Mobile in-app purchases are not used on the web.',
      );
    }

    final purchaseParam = PurchaseParam(
      productDetails: product,
    );

    await _iap.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> startWebCheckout(String productId) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Stripe Checkout is only used by the web app.',
      );
    }

    if (productId != monthlyId && productId != yearlyId) {
      throw ArgumentError(
        'Invalid subscription product.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'You must be signed in before subscribing.',
      );
    }

    final idToken = await user.getIdToken();

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Unable to authenticate your subscription request.',
      );
    }

    final interval = productId == monthlyId ? 'monthly' : 'yearly';

    final response = await http.post(
      Uri.parse(
        'https://us-central1-com-example-sparklearn.cloudfunctions.net/createSparkLearnStripeCheckoutHttp',
      ),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'interval': interval,
        'returnUrl': Uri.base.origin,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Stripe Checkout failed: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    final checkoutUrl = decoded['checkoutUrl']?.toString();

    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception(
        'Stripe Checkout did not return a checkout URL.',
      );
    }

    final checkoutUri = Uri.parse(checkoutUrl);

    final launched = await launchUrl(
      checkoutUri,
      webOnlyWindowName: '_self',
    );

    if (!launched) {
      throw Exception(
        'Unable to open Stripe Checkout.',
      );
    }
  }

  Future<void> restore() async {
    if (kIsWeb) return;

    await _iap.restorePurchases();
  }

  Future<bool> hasPremiumAccess() async {
    try {
      final callable = _functions.httpsCallable(
        'getPremiumEntitlement',
      );

      final result = await callable.call();

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      return data['premiumActive'] == true;
    } catch (e) {
      debugPrint(
        'Premium entitlement check failed: $e',
      );

      return false;
    }
  }

  Future<void> _handlePurchases(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final callable = _functions.httpsCallable(
          'verifyPremiumPurchase',
        );

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
