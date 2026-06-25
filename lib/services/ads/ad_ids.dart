import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

/// 배너가 들어가는 화면 위치. 위치마다 별도의 AdMob 광고 단위를 쓴다.
enum BannerPlacement { home, subjects, stats, settings, quiz }

/// AdMob 광고 단위 ID 모음.
///
/// **디버그 빌드에서는 항상 구글 공식 '테스트' 광고 단위**를 사용한다.
/// (자기 앱에서 실제 광고를 클릭하면 계정이 정지될 수 있으므로, 개발/QA 중에는
///  실수로라도 실제 광고가 나오지 않도록 자동 분기.)
/// 릴리스 빌드에서만 아래 운영 ID(게시자 pub-2707874353926722)를 사용한다.
class AdIds {
  AdIds._();

  static final bool _android = Platform.isAndroid;

  // ───────── 테스트 ID (구글 공식, 디버그 전용) ─────────
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';

  // ───────── 운영 배너 (화면별) ─────────
  static const Map<BannerPlacement, String> _bannerAndroid = {
    BannerPlacement.home: 'ca-app-pub-2707874353926722/3342640326',
    BannerPlacement.subjects: 'ca-app-pub-2707874353926722/4762964980',
    BannerPlacement.stats: 'ca-app-pub-2707874353926722/9823719979',
    BannerPlacement.settings: 'ca-app-pub-2707874353926722/3151068632',
    BannerPlacement.quiz: 'ca-app-pub-2707874353926722/7197556633',
  };

  static const Map<BannerPlacement, String> _bannerIos = {
    BannerPlacement.home: 'ca-app-pub-2707874353926722/5431003224',
    BannerPlacement.subjects: 'ca-app-pub-2707874353926722/8047603878',
    BannerPlacement.stats: 'ca-app-pub-2707874353926722/5594654750',
    BannerPlacement.settings: 'ca-app-pub-2707874353926722/7123358844',
    BannerPlacement.quiz: 'ca-app-pub-2707874353926722/7720869031',
  };

  // ───────── 운영 전면(전환형) ─────────
  static const String _interstitialAndroid =
      'ca-app-pub-2707874353926722/6814413258';
  static const String _interstitialIos =
      'ca-app-pub-2707874353926722/3641455007';

  // ───────── 운영 보상형(힌트) ─────────
  static const String _rewardedAndroid =
      'ca-app-pub-2707874353926722/5144208552';
  static const String _rewardedIos =
      'ca-app-pub-2707874353926722/2359665484';

  static String banner(BannerPlacement placement) {
    if (kDebugMode) return _android ? _testBannerAndroid : _testBannerIos;
    return (_android ? _bannerAndroid : _bannerIos)[placement]!;
  }

  static String get interstitial {
    if (kDebugMode) {
      return _android ? _testInterstitialAndroid : _testInterstitialIos;
    }
    return _android ? _interstitialAndroid : _interstitialIos;
  }

  static String get rewarded {
    if (kDebugMode) {
      return _android ? _testRewardedAndroid : _testRewardedIos;
    }
    return _android ? _rewardedAndroid : _rewardedIos;
  }
}
