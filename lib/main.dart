import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/ads/ad_service.dart';
import 'services/inquiry_service.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

// Google 웹 클라이언트 ID / Kakao 네이티브 앱 키는 비밀값이 아니라 기본값으로 박아둔다.
// 다른 값을 쓰고 싶을 때만 --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx / KAKAO_NATIVE_APP_KEY=xxx 로 덮어쓰면 된다.
const _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '710033231798-rbfk8luqljcguqf5lm50s17g7s9aiamn.apps.googleusercontent.com',
);
const _kakaoNativeAppKey = String.fromEnvironment(
  'KAKAO_NATIVE_APP_KEY',
  defaultValue: '5d96aa78e032d9f1e91f2dffe4dd2cbd',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await NotificationService.init();
  // 광고 SDK 초기화(설치 시각 기록 + 전면 광고 프리로드). 첫 프레임을 막지 않도록 await 하지 않음.
  AdService.instance.init(prefs);
  // 어드민 DAU/WAU/MAU 통계용 ping. 로그인 여부 무관(게스트 포함) — 마찬가지로 await 안 함.
  InquiryService(prefs).pingDevice();
  await _initSocialLoginSdks();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AdultMathApp(),
    ),
  );
}

/// Google/Kakao SDK는 사용 전 1회 초기화가 필요하다. 콘솔 설정 전(플레이스홀더 값)에도
/// 앱 시작을 막지 않도록 실패는 무시한다 — 로그인 버튼만 동작하지 않게 된다.
/// (디버그 빌드에선 초기화 실패와 Kakao SDK 내부 로그를 콘솔에 남긴다.)
Future<void> _initSocialLoginSdks() async {
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          _googleServerClientId.isEmpty ? null : _googleServerClientId,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[Auth] GoogleSignIn.initialize 실패: $e');
  }
  try {
    await KakaoSdk.init(
      nativeAppKey: _kakaoNativeAppKey.isEmpty ? 'unset' : _kakaoNativeAppKey,
      loggingEnabled: kDebugMode,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[Auth] KakaoSdk.init 실패: $e');
  }
}
