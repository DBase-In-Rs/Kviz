import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

const kvizNoAdsMonthlyProductId = String.fromEnvironment(
  'KVIZ_IAP_NO_ADS_MONTHLY_ID',
  defaultValue: 'kviz_no_ads_monthly',
);
const kvizPremierMonthlyProductId = String.fromEnvironment(
  'KVIZ_IAP_PREMIER_MONTHLY_ID',
  defaultValue: 'kviz_premier_monthly',
);

const kvizIapProductIds = <String>{
  kvizNoAdsMonthlyProductId,
  kvizPremierMonthlyProductId,
};

class KvizPurchaseUpdate {
  const KvizPurchaseUpdate({
    required this.productId,
    required this.status,
    this.purchaseToken,
    this.errorMessage,
  });

  final String productId;
  final PurchaseStatus status;
  final String? purchaseToken;
  final String? errorMessage;
}

class KvizIapService {
  KvizIapService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;
  final StreamController<KvizPurchaseUpdate> _updates =
      StreamController<KvizPurchaseUpdate>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Stream<KvizPurchaseUpdate> get updates => _updates.stream;

  void start() {
    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _updates.add(
          KvizPurchaseUpdate(
            productId: '',
            status: PurchaseStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  Future<bool> isAvailable() {
    return _inAppPurchase.isAvailable();
  }

  Future<ProductDetailsResponse> queryProducts(Set<String> productIds) {
    return _inAppPurchase.queryProductDetails(productIds);
  }

  Future<bool> buySubscription(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() {
    return _inAppPurchase.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _updates.add(
        KvizPurchaseUpdate(
          productId: purchase.productID,
          status: purchase.status,
          purchaseToken: purchase.verificationData.serverVerificationData,
          errorMessage: purchase.error?.message,
        ),
      );

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _updates.close();
  }
}
