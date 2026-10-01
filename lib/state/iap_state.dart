import 'dart:async';
import 'dart:io' show Platform;

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

/// [decideIapOutcome]이 내리는 판단. 부수효과(상태 반영·네트워크 push·스토어 완료 처리)는
/// 전부 [IapNotifier]가 하고, 여기선 "무엇을 해야 하는지"만 순수하게 계산한다 — 그래야
/// 네트워크·스토어 SDK 없이 핵심 분기(검증 실패 시 미완료 유지, 로그인 안 됨, 중복 지급
/// 안 함 등)를 단위 테스트할 수 있다.
enum IapOutcome { needsLogin, retryLater, rejected, noGrant, grantedCoupons, grantedAdsRemoved }

class IapDecision {
  final IapOutcome outcome;
  /// true면 스토어 트랜잭션을 완료 처리(completePurchase)해도 안전 — 서버가 확정
  /// 응답을 줬다는 뜻. false면 완료 처리하지 않고 다음 실행 때 재시도되게 둔다.
  final bool shouldComplete;
  final String? message;
  final int coupons;

  const IapDecision({
    required this.outcome,
    required this.shouldComplete,
    this.message,
    this.coupons = 0,
  });
}

/// 서버 검증 결과(또는 못 받았다는 사실)로부터 무엇을 할지 판단하는 순수 함수.
/// - [token]이 없으면(로그인 안 됨) 완료 처리하지 않는다 — 로그인 후 재시도됨.
/// - [hadError]면(네트워크/서버 오류로 확정 응답을 못 받음) 완료 처리하지 않는다 —
///   안 그러면 결제는 되는데 지급은 안 되는 사고가 날 수 있다.
/// - 서버가 확정 응답을 줬으면(verified true/false 무관) 완료 처리는 항상 안전하다.
/// - `coupons`는 서버가 이미 처리된 트랜잭션이면 0을 내려주므로(재지급 방지), 그대로
///   신뢰하고 0이면 지급하지 않는다(noGrant) — 클라이언트가 별도로 중복을 걸러낼 필요 없음.
IapDecision decideIapOutcome({
  required String? token,
  required IapVerifyResult? result,
  required bool hadError,
}) {
  if (token == null) {
    return const IapDecision(
      outcome: IapOutcome.needsLogin,
      shouldComplete: false,
      message: '로그인 상태에서만 구매가 반영돼요',
    );
  }
  if (hadError || result == null) {
    return const IapDecision(
      outcome: IapOutcome.retryLater,
      shouldComplete: false,
      message: '네트워크 오류로 구매 확인을 못했어요. 앱을 다시 열면 재시도돼요',
    );
  }
  if (!result.verified) {
    return const IapDecision(
      outcome: IapOutcome.rejected,
      shouldComplete: true,
      message: '구매 확인에 실패했어요',
    );
  }
  if (result.kind == 'hint_coupons' && result.coupons > 0) {
    return IapDecision(
      outcome: IapOutcome.grantedCoupons,
      shouldComplete: true,
      coupons: result.coupons,
      message: '힌트쿠폰 ${result.coupons}개가 지급됐어요',
    );
  }
  if (result.kind == 'remove_ads') {
    return const IapDecision(
      outcome: IapOutcome.grantedAdsRemoved,
      shouldComplete: true,
      message: '광고가 제거됐어요',
    );
  }
  // verified:true인데 지급할 게 없음(예: 이미 처리된 힌트쿠폰 재검증 — 서버가 coupons:0 반환).
  return const IapDecision(outcome: IapOutcome.noGrant, shouldComplete: true);
}

/// 실제 스토어 가격 문자열(현지화 포함). 콘솔에 상품이 아직 없거나 조회 전이면 null —
/// 확정 안 된 가격을 함부로 하드코딩해서 보여주지 않기 위함(호출부가 폴백 문구를 결정).
String? iapPriceOf(IapState iap, String productId) => iap.products[productId]?.price;

class IapState {
  final bool busy;
  final String? message; // 스낵바로 한 번 보여주고 넘길 안내/에러 메시지
  final Map<String, ProductDetails> products; // 상점 UI에 실제 스토어 가격 표시용

  const IapState({this.busy = false, this.message, this.products = const {}});

  IapState copyWith({
    bool? busy,
    String? message,
    bool clearMessage = false,
    Map<String, ProductDetails>? products,
  }) => IapState(
    busy: busy ?? this.busy,
    message: clearMessage ? null : (message ?? this.message),
    products: products ?? this.products,
  );
}

/// 구매 오케스트레이션: 로그인 확인 → 스토어 구매 요청 → (구매 스트림) 서버 검증 →
/// 검증 통과 시 힌트쿠폰 지급/광고 제거 반영. [IapService]는 순수 I/O만, 상태 반영은 여기서.
class IapNotifier extends StateNotifier<IapState> {
  final IapService _iap;
  final AuthService _auth;
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// buy() 호출 시점의 로그인 토큰(같은 프로세스 내 빠른 경로용 메모리 캐시).
  /// **영구 보관은 [AuthService.savePendingPurchaseToken]가 담당** — 앱이 완전히
  /// 꺼졌다 재시작된 뒤에 구매가 완료되는 경우(가족 승인 대기 등)엔 이 메모리 값이
  /// 사라지므로, 실제 귀속 판단은 항상 영구 저장값을 우선 확인한다.
  /// 복원(restore)으로 들어온 건은 이 값이 없으므로 자연스럽게 "현재 로그인 계정"으로 검증된다.
  String? _initiatorToken;

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
    _loadProducts();
  }

  /// 상점 UI에 하드코딩 가격 대신 실제 스토어 가격(통화·현지화 포함)을 보여주기 위해
  /// 미리 조회해둔다. 콘솔에 상품이 아직 없으면 빈 채로 남고, UI가 폴백 문구를 쓴다.
  Future<void> _loadProducts() async {
    try {
      final products = await _iap.queryProducts(IapService.productIds);
      if (products.isNotEmpty) state = state.copyWith(products: products);
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 상품 정보 조회 실패: $e');
    }
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
    final token = await _auth.cachedToken;
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
      // 구매 요청 자체에 계정 식별자를 심어서, 스토어가 서명한 영수증만으로도 서버가
      // "이 구매가 원래 어느 계정 건지" 확인할 수 있게 한다(로그인 토큰과는 독립적인
      // 신호라, JWT가 만료돼도 계정 귀속 정보는 살아남는다).
      final accountUuid = _ref.read(authProvider).user?.iapAccountUuid;
      final started = productId == IapService.kHintCoupons10Id
          ? await _iap.buyConsumable(details, accountUuid: accountUuid)
          : await _iap.buyNonConsumable(details, accountUuid: accountUuid);
      if (started) {
        // 플랫폼에 실제로 구매 요청이 들어간 뒤에만 귀속 정보를 저장한다 — 그 전에
        // 저장해버리면, 이 시도가 실패해도 슬롯을 차지해서 다른 미해결 구매 건의
        // 저장값을 덮어쓸 위험이 있다(슬롯이 1개뿐이라). 영구 저장은 앱이 꺼졌다
        // 재시작된 뒤 구매가 완료되는 경우에도 "결제를 시작한 계정"을 알기 위함
        // (메모리 캐시는 프로세스 재시작 시 사라짐).
        _initiatorToken = token;
        await _auth.savePendingPurchaseToken(token);
        // 성공 결과는 purchaseStream을 통해 비동기로 들어옴 — busy는 그때 내림.
      } else {
        state = state.copyWith(busy: false, message: '구매를 시작하지 못했어요');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 구매 시작 실패: $e');
      state = state.copyWith(busy: false, message: '구매를 시작하지 못했어요');
    }
  }

  Future<void> restore() async {
    if (!_ref.read(authProvider).loggedIn) {
      state = state.copyWith(message: '로그인이 필요해요');
      return;
    }
    state = state.copyWith(busy: true, clearMessage: true);
    try {
      // restorePurchases()는 복원 "요청"이 접수됐다는 뜻일 뿐, 실제 복원 건은
      // purchaseStream으로 비동기 전달된다. 복원할 게 없으면 아무 이벤트도 안 와서
      // busy가 안 풀릴 수 있으므로 요청 완료 시점에 한 번 내려준다(있으면 아래에서 다시 세팅됨).
      await _iap.restore();
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 구매 복원 실패: $e');
      state = state.copyWith(message: '구매 복원에 실패했어요');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // completePurchase는 _verifyAndApply 내부에서, 서버가 확정 응답을 줬을 때만 호출한다.
          await _verifyAndApply(p);
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('[IAP] 구매 오류: ${p.error}');
          state = state.copyWith(busy: false, message: '구매 중 오류가 발생했어요');
          _initiatorToken = null;
          await _clearPendingTokenIfNotRestore(p);
          // 검증을 거치지 않은 건이라 consume은 절대 호출하지 않는다(_finishPurchase는
          // "서버가 검증을 확정한 뒤"에만 쓰는 함수 — 여긴 확인/acknowledge만 필요하면 함).
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(busy: false);
          _initiatorToken = null;
          await _clearPendingTokenIfNotRestore(p);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  /// 복원 건은 애초에 저장된 귀속 토큰을 쓰지 않으므로(항상 "현재 로그인 계정" 기준),
  /// 여기서도 건드리지 않는다 — 지우면 다른 미해결 구매 건의 귀속 정보가 날아갈 수 있다.
  Future<void> _clearPendingTokenIfNotRestore(PurchaseDetails p) async {
    if (p.status != PurchaseStatus.restored) {
      await _auth.savePendingPurchaseToken(null);
    }
  }

  /// 구매/복원된 트랜잭션을 서버로 검증하고, [decideIapOutcome]의 판단대로 반영한다.
  Future<void> _verifyAndApply(PurchaseDetails p) async {
    state = state.copyWith(busy: true, clearMessage: true);
    final String? token;
    if (p.status == PurchaseStatus.restored) {
      // 복원(restore())은 정의상 "지금 로그인된 계정"으로 가져오는 동작이라, buy()가
      // 남겨둔 귀속 정보(다른 거래의 것일 수 있음)를 써서는 안 된다.
      token = await _auth.cachedToken;
    } else {
      // 신규 구매(.purchased) — "결제를 시작한 계정" 토큰을 우선 사용. 그사이 로그아웃/
      // 계정 전환이 있었어도 엉뚱한 계정에 지급되지 않는다. 메모리 캐시(같은 프로세스)
      // → 영구 저장값(앱이 꺼졌다 재시작된 뒤 도착한 경우) → 현재 로그인 계정 순.
      token =
          _initiatorToken ?? await _auth.pendingPurchaseToken ?? await _auth.cachedToken;
    }
    _initiatorToken = null;

    IapVerifyResult? result;
    var hadError = false;
    if (token != null) {
      try {
        result = await _iap.verify(token, p);
      } on IapVerifyAuthError {
        // 이 토큰은 만료/무효 — 같은 값으로는 영원히 재시도해봐야 또 실패한다.
        // 저장해둔 귀속 정보를 지워서, 다음 시도부턴 그 시점의 최신 로그인 토큰을
        // 쓰게 한다(로그인 상태면 다음 앱 실행/재시도 때 자연히 해결됨).
        if (kDebugMode) debugPrint('[IAP] 검증 토큰 만료/무효 — 귀속 정보 초기화');
        await _clearPendingTokenIfNotRestore(p);
        hadError = true;
      } catch (e) {
        if (kDebugMode) debugPrint('[IAP] 검증 요청 실패(재시도 예정): $e');
        hadError = true;
      }
    }

    final decision = decideIapOutcome(token: token, result: result, hadError: hadError);
    switch (decision.outcome) {
      case IapOutcome.grantedCoupons:
        _ref.read(statsProvider.notifier).addHintCoupons(decision.coupons);
        // 동기화 실패는 별도로 잡는다 — 지급 자체(로컬 반영)는 이미 끝났고, 구매도
        // 서버가 이미 확정했으므로 여기서 예외가 나도 거래 완료 처리는 계속 진행해야
        // 한다. 동기화는 다음 "지금 동기화"나 재로그인 때 다시 시도된다.
        try {
          final sync = _ref.read(syncServiceProvider);
          await sync.push(token!, _ref.read(statsProvider), _ref.read(settingsProvider));
        } catch (e) {
          if (kDebugMode) debugPrint('[IAP] 지급 후 동기화 실패(나중에 재시도됨): $e');
        }
        break;
      case IapOutcome.grantedAdsRemoved:
        _ref.read(adsRemovedProvider.notifier).setRemoved(true);
        break;
      case IapOutcome.needsLogin:
      case IapOutcome.retryLater:
      case IapOutcome.rejected:
      case IapOutcome.noGrant:
        break;
    }
    state = state.copyWith(busy: false, message: decision.message);
    // shouldComplete=false면(로그인 안 됨/네트워크 오류로 확정 응답을 못 받음) 완료 처리하지
    // 않고, 영구 저장된 귀속 토큰도 그대로 남겨둔다 — 그래야 다음 앱 실행 때
    // purchaseStream으로 다시 전달됐을 때도 같은 계정으로 재시도된다.
    // (완료 처리부터 해버리면 결제는 되는데 지급은 안 되는 사고가 날 수 있음.)
    if (decision.shouldComplete) {
      await _clearPendingTokenIfNotRestore(p); // 거래 종결 — 보관해둔 귀속 정보 정리
      await _finishPurchase(p);
    }
  }

  /// 스토어 트랜잭션을 최종 마무리한다. **`decideIapOutcome`이 `shouldComplete:true`를
  /// 준(=서버 검증이 확정 응답을 준) 건에만 호출할 것** — Android 소모성 상품은 검증도
  /// 안 거친 `.error`/`.canceled` 건에 이걸 쓰면 안 됨(consume을 호출해버리면 검증 전
  /// 트랜잭션이 영구 소비돼서 재시도 불가능해짐). 그 케이스들은 이 함수를 쓰지 않고
  /// 단순 completePurchase만 한다(`_onPurchaseUpdate` 참고).
  ///
  /// Android 소모성 상품(힌트쿠폰)은 buyConsumable을 autoConsume:false로 호출했으므로,
  /// completePurchase(확인/acknowledge)가 아니라 consume을 직접 호출해야 한다 —
  /// consume이 확인도 겸하고, 이래야 사용자가 같은 상품을 다시 살 수 있게 풀린다.
  /// 그 외(iOS 전체, Android 비소모성)는 completePurchase로 충분.
  Future<void> _finishPurchase(PurchaseDetails p) async {
    try {
      if (Platform.isAndroid && p.productID == IapService.kHintCoupons10Id) {
        await _iap.consumeAndroidPurchase(p);
      } else if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[IAP] 거래 마무리(consume/complete) 실패: $e');
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
