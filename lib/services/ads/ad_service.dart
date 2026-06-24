import 'dart:math' as math;

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
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdMob 초기화 실패: $e');
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
}
