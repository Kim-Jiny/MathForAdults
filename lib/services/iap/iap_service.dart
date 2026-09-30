import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// 서버 `/iap/verify` 응답.
class IapVerifyResult {
  final bool verified;
  final String? kind; // remove_ads | hint_coupons
  final int coupons;

  const IapVerifyResult({required this.verified, this.kind, this.coupons = 0});

  factory IapVerifyResult.fromJson(Map<String, dynamic> j) => IapVerifyResult(
    verified: j['verified'] == true,
    kind: j['kind'] as String?,
    coupons: (j['coupons'] as num?)?.toInt() ?? 0,
  );
}

/// 인앱결제 — 상품 조회/구매 요청/영수증 서버 검증. 순수 스토어·네트워크 I/O만 담당하고
/// 구매 성공 시 앱 상태(힌트쿠폰/광고제거)에 반영하는 오케스트레이션은 [IapNotifier]가 한다.
class IapService {
  static const _base = 'https://duo.jiny.shop/api/mathforadults';

  // 서버 mfaIap.ts의 MFA_PRODUCTS와 반드시 일치해야 함.
  static const kRemoveAdsId = 'remove_ads';
  static const kHintCoupons10Id = 'hint_coupons_10';
  static const productIds = {kRemoveAdsId, kHintCoupons10Id};

  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  Future<ProductDetails?> queryProduct(String productId) async {
    final res = await InAppPurchase.instance.queryProductDetails({productId});
    if (res.productDetails.isEmpty) return null;
    return res.productDetails.first;
  }

  /// 상점 UI에 실제 스토어 가격(통화·현지화 포함)을 표시하기 위한 일괄 조회.
  /// 콘솔에 상품이 아직 없으면 빈 맵을 돌려준다(호출부가 하드코딩 폴백 문구로 대체).
  Future<Map<String, ProductDetails>> queryProducts(Set<String> ids) async {
    final res = await InAppPurchase.instance.queryProductDetails(ids);
    return {for (final d in res.productDetails) d.id: d};
  }

  Future<bool> buyConsumable(ProductDetails details) =>
      InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );

  Future<bool> buyNonConsumable(ProductDetails details) =>
      InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );

  Future<void> completePurchase(PurchaseDetails p) =>
      InAppPurchase.instance.completePurchase(p);

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  /// 구매 영수증을 서버로 보내 검증. 플랫폼별로 필요한 값이 다르다
  /// (iOS: JWS 하나, Android: originalJson+signature 둘 다 필요 — 일반
  /// `verificationData.serverVerificationData`엔 signature가 없어서 Android는
  /// `GooglePlayPurchaseDetails.billingClientPurchase`에서 따로 꺼내야 한다).
  ///
  /// 네트워크 오류·서버 오류(비2xx)는 예외로 던진다(호출부가 "서버가 확정 응답을
  /// 못 줬다"와 "서버가 검증 결과를 줬다(verified true/false)"를 구분해서, 전자일 땐
  /// 스토어 트랜잭션을 completePurchase 하지 않고 다음 실행 때 재시도하게 하기 위함 —
  /// 안 그러면 결제는 되고 지급은 안 되는 사고가 날 수 있다).
  Future<IapVerifyResult> verify(String token, PurchaseDetails p) async {
    final Map<String, dynamic> body;
    if (Platform.isIOS) {
      body = {
        'platform': 'ios',
        'productId': p.productID,
        'transactionId': p.purchaseID ?? '',
        'payload': p.verificationData.serverVerificationData,
      };
    } else {
      final gp = p as GooglePlayPurchaseDetails;
      final purchase = gp.billingClientPurchase;
      body = {
        'platform': 'android',
        'productId': p.productID,
        'transactionId': purchase.orderId,
        'payload': purchase.originalJson,
        'signature': purchase.signature,
      };
    }
    final res = await http
        .post(
          Uri.parse('$_base/iap/verify'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('영수증 검증 요청 실패 (${res.statusCode})');
    }
    return IapVerifyResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<bool> fetchAdsRemoved(String token) async {
    final res = await http.get(
      Uri.parse('$_base/entitlements'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) return false;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['adsRemoved'] == true;
  }
}

final iapServiceProvider = Provider<IapService>((_) => IapService());
