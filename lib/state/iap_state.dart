import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth/auth_service.dart';
import '../services/auth/sync_service.dart';
import '../services/iap/iap_service.dart';
import 'app_state.dart';
import 'auth_state.dart';

const _kAdsRemovedKey = 'mfa_ads_removed';

/// 광고 제거 여부. 로컬에 영구 저장 + 로그인 시 서버 엔타이틀먼트로 복원(다른 기기 구매 포함).
class AdsRemovedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  AdsRemovedNotifier(this._prefs) : super(_prefs.getBool(_kAdsRemovedKey) ?? false);

  void setRemoved(bool v) {
    if (state == v) return;
    state = v;
    _prefs.setBool(_kAdsRemovedKey, v);
  }
}

final adsRemovedProvider = StateNotifierProvider<AdsRemovedNotifier, bool>(
  (ref) => AdsRemovedNotifier(ref.watch(sharedPreferencesProvider)),
);

class IapState {
  final bool busy;
  final String? message; // 스낵바로 한 번 보여주고 넘길 안내/에러 메시지

  const IapState({this.busy = false, this.message});

  IapState copyWith({bool? busy, String? message, bool clearMessage = false}) =>
      IapState(
        busy: busy ?? this.busy,
        message: clearMessage ? null : (message ?? this.message),
      );
}

/// 구매 오케스트레이션: 로그인 확인 → 스토어 구매 요청 → (구매 스트림) 서버 검증 →
/// 검증 통과 시 힌트쿠폰 지급/광고 제거 반영. [IapService]는 순수 I/O만, 상태 반영은 여기서.
class IapNotifier extends StateNotifier<IapState> {
  final IapService _iap;
  final AuthService _auth;
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  IapNotifier(this._iap, this._auth, this._ref) : super(const IapState()) {
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (e) {
      if (kDebugMode) debugPrint('[IAP] 구매 스트림 오류: $e');
    });
    // 이미 로그인된 상태로 앱이 시작됐으면 계정 기준 엔타이틀먼트(광고 제거) 복원.
    if (_ref.read(authProvider).loggedIn) _refreshEntitlements();
    // 이후 로그인 성공 시점에도 복원(다른 기기에서 산 광고 제거를 여기서도 반영).
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.loggedIn && prev?.loggedIn != true) _refreshEntitlements();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshEntitlements() async {
    final token = await _auth.cachedToken;
    if (token == null) return;
    try {
      final removed = await _iap.fetchAdsRemoved(token);
      if (removed) _ref.read(adsRemovedProvider.notifier).setRemoved(true);
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 엔타이틀먼트 조회 실패: $e');
    }
  }

  /// 상품 구매 시작. 로그인 안 돼 있으면 시작하지 않고 에러 메시지만 세팅
  /// (버튼 쪽에서도 미리 로그인 유도하는 게 원칙이지만, 여기서도 한 번 더 막는다).
  Future<void> buy(String productId) async {
    if (!_ref.read(authProvider).loggedIn) {
      state = state.copyWith(message: '로그인이 필요해요', clearMessage: false);
      return;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        state = state.copyWith(busy: false, message: '스토어를 사용할 수 없어요');
        return;
      }
      final details = await _iap.queryProduct(productId);
      if (details == null) {
        state = state.copyWith(busy: false, message: '상품 정보를 불러오지 못했어요');
        return;
      }
      final started = productId == IapService.kHintCoupons10Id
          ? await _iap.buyConsumable(details)
          : await _iap.buyNonConsumable(details);
      if (!started) {
        state = state.copyWith(busy: false, message: '구매를 시작하지 못했어요');
      }
      // 성공 결과는 purchaseStream을 통해 비동기로 들어옴 — busy는 그때 내림.
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 구매 시작 실패: $e');
      state = state.copyWith(busy: false, message: '구매를 시작하지 못했어요');
    }
  }

  Future<void> restore() async {
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      await _iap.restore();
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 구매 복원 실패: $e');
      state = state.copyWith(busy: false, message: '구매 복원에 실패했어요');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndApply(p);
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('[IAP] 구매 오류: ${p.error}');
          state = state.copyWith(busy: false, message: '구매 중 오류가 발생했어요');
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(busy: false);
          break;
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _verifyAndApply(PurchaseDetails p) async {
    final token = await _auth.cachedToken;
    if (token == null) {
      // 로그인 없이 들어온 구매(비정상 경로)는 지급하지 않는다 — 구매는 로그인 필수 정책.
      state = state.copyWith(busy: false, message: '로그인 상태에서만 구매가 반영돼요');
      return;
    }
    try {
      final result = await _iap.verify(token, p);
      if (!result.verified) {
        state = state.copyWith(busy: false, message: '구매 확인에 실패했어요');
        return;
      }
      if (result.kind == 'hint_coupons' && result.coupons > 0) {
        _ref.read(statsProvider.notifier).addHintCoupons(result.coupons);
        final sync = _ref.read(syncServiceProvider);
        await sync.push(
          token,
          _ref.read(statsProvider),
          _ref.read(settingsProvider),
        );
        state = state.copyWith(busy: false, message: '힌트쿠폰 ${result.coupons}개가 지급됐어요');
      } else if (result.kind == 'remove_ads') {
        _ref.read(adsRemovedProvider.notifier).setRemoved(true);
        state = state.copyWith(busy: false, message: '광고가 제거됐어요');
      } else {
        state = state.copyWith(busy: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 검증 실패: $e');
      state = state.copyWith(busy: false, message: '구매 확인에 실패했어요');
    }
  }
}

final iapProvider = StateNotifierProvider<IapNotifier, IapState>((ref) {
  return IapNotifier(
    ref.watch(iapServiceProvider),
    ref.watch(authServiceProvider),
    ref,
  );
});
