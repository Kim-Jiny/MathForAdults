import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_ids.dart';

/// 전면(전환형) 광고 노출 정책을 담당하는 싱글톤.
///
/// 노출 규칙(일반 문제 풀이의 채점/다음 문제 전환 시점에서만 호출):
///  - 모의수능 세션에서는 절대 노출하지 않음
///  - 앱 설치 후 30분이 지난 사용자에게만
///  - 직전 광고를 본 뒤 3분(쿨타임)이 지나야
///  - 위 조건을 모두 통과한 전환의 20% 확률로만
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _kInstallAtKey = 'ads_install_at_ms';
  static const _kLastShownKey = 'ads_last_interstitial_ms';

  static const _minAgeAfterInstall = Duration(minutes: 30);
  static const _cooldown = Duration(minutes: 3);
  static const _showProbability = 0.20;

  final _rand = math.Random();

  SharedPreferences? _prefs;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  bool _initialized = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;
  // 보상형(힌트) 광고 준비 여부 — UI가 구독해 힌트 버튼 활성화 상태를 갱신한다.
  final ValueNotifier<bool> _rewardedReady = ValueNotifier<bool>(false);

  /// main()에서 1회 호출. SDK 초기화 + 설치 시각 기록 + 첫 전면 광고 프리로드.
  Future<void> init(SharedPreferences prefs) async {
    if (_initialized) return;
    _initialized = true;
    _prefs = prefs;

    // 설치(최초 실행) 시각을 30분 게이트 기준으로 기록.
    if (!prefs.containsKey(_kInstallAtKey)) {
      await prefs.setInt(
          _kInstallAtKey, DateTime.now().millisecondsSinceEpoch);
    }

    try {
      // 광고 SDK 초기화 전에 동의를 먼저 처리한다:
      // (1) Google UMP(GDPR/EEA) 동의, (2) iOS ATT(추적 동의).
      await _gatherConsentAndAtt();
      await MobileAds.instance.initialize();
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
    }
  }

  /// 광고 SDK 초기화 전 동의 수집: Google UMP(GDPR) → iOS ATT 순서.
  /// 어느 단계가 실패해도 광고 초기화는 진행한다(비맞춤형으로 폴백).
  Future<void> _gatherConsentAndAtt() async {
    // 1) Google UMP: 동의 정보 갱신 + (필요 시) 동의 폼 표시.
    try {
      final completer = Completer<void>();
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('UMP 동의 폼 오류: ${formError.message}');
              }
            });
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (requestError) {
          debugPrint('UMP 정보 갱신 오류: ${requestError.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
    } catch (e) {
      debugPrint('UMP 처리 실패: $e');
    }

    // 2) iOS ATT: 아직 결정되지 않았을 때만 추적 동의 프롬프트 표시.
    if (Platform.isIOS) {
      try {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (e) {
        debugPrint('ATT 요청 실패: $e');
      }
    }
  }

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _loadingInterstitial = false;
          debugPrint('전면 광고 로드 실패: $error');
        },
      ),
    );
  }

  /// 일반 문제 풀이의 전환 시점에서 호출. 정책을 모두 만족하면 전면 광고를 띄운다.
  ///
  /// [isMockExam] 가 true(모의수능)면 아무 것도 하지 않는다.
  void maybeShowInterstitial({required bool isMockExam}) {
    if (!_initialized || isMockExam) return;

    final prefs = _prefs;
    if (prefs == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 설치 30분 경과 게이트
    final installAt = prefs.getInt(_kInstallAtKey) ?? now;
    if (now - installAt < _minAgeAfterInstall.inMilliseconds) return;

    // 3분 쿨타임 게이트
    final lastShown = prefs.getInt(_kLastShownKey) ?? 0;
    if (now - lastShown < _cooldown.inMilliseconds) return;

    // 광고가 아직 준비되지 않았으면 다음을 위해 미리 로드만 하고 종료
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    // 20% 확률
    if (_rand.nextDouble() >= _showProbability) return;

    // 노출 확정 — 쿨타임 시작점 기록 후 표시.
    prefs.setInt(_kLastShownKey, now);
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial(); // 다음 노출용 프리로드
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        debugPrint('전면 광고 표시 실패: $error');
      },
    );
    ad.show();
  }

  void _loadRewarded() {
    if (_loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          _rewarded = null;
          _loadingRewarded = false;
          _rewardedReady.value = false;
          debugPrint('보상형 광고 로드 실패: $error');
        },
      ),
    );
  }

  /// 보상형(힌트) 광고가 지금 노출 준비됐는지.
  bool get isRewardedReady => _rewarded != null;

  /// 보상형 광고 준비 여부를 구독할 수 있는 리스너블(힌트 버튼 활성화용).
  ValueListenable<bool> get rewardedReadyListenable => _rewardedReady;

  /// 보상형 광고를 미리 로드해 둔다(준비 안 됐을 때 다음 노출 대비).
  void preloadRewarded() => _loadRewarded();

  /// 힌트 잠금 해제용 보상형 광고를 띄운다.
  ///
  /// 사용자가 광고를 끝까지 보고 보상을 획득하면 true, 광고가 준비되지 않았거나
  /// 표시에 실패하면 false를 반환한다(이 경우 호출 측에서 힌트를 그대로 열어 줄지 결정).
  /// 광고가 닫힌 뒤에 결과가 확정되도록 dismiss 콜백에서 완료한다.
  Future<bool> showRewardedForHint() async {
    if (!_initialized) return false;

    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded(); // 다음 기회를 위해 미리 로드
      return false;
    }

    _rewarded = null; // 같은 광고 객체 재사용 방지
    _rewardedReady.value = false;
    final completer = Completer<bool>();
    var earned = false;

    void finish(bool result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded(); // 다음 노출용 프리로드
        finish(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewarded();
        debugPrint('보상형 광고 표시 실패: $error');
        finish(false);
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      earned = true;
    });

    return completer.future;
  }
}
