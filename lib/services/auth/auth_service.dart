import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 로그인 제공자. 서버 `mfa_users.provider` 값과 1:1 대응.
enum AuthProvider { google, apple, kakao }

/// 서버 `/auth/social` 응답의 유저 정보.
class AuthUser {
  final int id;
  final String? nickname;
  final String? email;
  /// 인앱결제 구매 요청에 심는 계정 식별자(iOS appAccountToken / Android
  /// obfuscatedAccountId로 매핑됨). 스토어가 서명한 영수증에 그대로 남아서, 서버가
  /// JWT 유효기간과 무관하게 "이 영수증이 원래 어느 계정 건지" 대조할 수 있게 해준다.
  final String? iapAccountUuid;

  const AuthUser({
    required this.id,
    this.nickname,
    this.email,
    this.iapAccountUuid,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as int,
    nickname: j['nickname'] as String?,
    email: j['email'] as String?,
    iapAccountUuid: j['iapAccountUuid'] as String?,
  );
}

/// 소셜 로그인 + JWT 보관. 학습기록 자체는 다루지 않음(SyncService 담당).
///
/// Google/Apple/Kakao 콘솔 설정(클라이언트 ID·네이티브 앱 키 등)이 비어 있으면
/// 로그인 시도만 실패하고 나머지 기능엔 영향 없음(docs/소셜로그인_설정.md 참고).
class AuthService {
  static const _base = 'https://duo.jiny.shop/api/mathforadults';
  static const _tokenKey = 'mfa_jwt';
  static const _userKey = 'mfa_user_json';
  static const _pendingIapTokenKey = 'mfa_pending_iap_token';

  final FlutterSecureStorage _storage;
  AuthService(this._storage);

  Future<String?> get cachedToken => _storage.read(key: _tokenKey);

  Future<AuthUser?> get cachedUser async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> loginWithGoogle() async {
    final google = GoogleSignIn.instance;
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google 로그인 토큰을 가져오지 못했어요');
    }
    return _authSocial(provider: 'google', body: {'idToken': idToken});
  }

  Future<AuthUser> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception('Apple 로그인 토큰을 가져오지 못했어요');
    }
    return _authSocial(provider: 'apple', body: {'idToken': idToken});
  }

  Future<AuthUser> loginWithKakao() async {
    final OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
    return _authSocial(
      provider: 'kakao',
      body: {'accessToken': token.accessToken},
    );
  }

  Future<AuthUser> _authSocial({
    required String provider,
    required Map<String, String> body,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/auth/social'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'provider': provider, ...body}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('로그인 실패 (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: token);
    await _cacheUser(user);
    return user;
  }

  /// 닉네임 변경. 카카오는 비즈 앱 인증 전엔 닉네임을 안 줘서 서버가 가입 시
  /// `guest-xxxxxx` 기본값을 부여하는데, 그걸 원하는 이름으로 바꿀 때 쓴다.
  Future<AuthUser> updateNickname(String nickname) async {
    final token = await cachedToken;
    if (token == null) throw Exception('로그인이 필요해요');
    final res = await http
        .put(
          Uri.parse('$_base/auth/nickname'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'nickname': nickname.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('닉네임 변경 실패 (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _cacheUser(user);
    return user;
  }

  Future<void> _cacheUser(AuthUser user) => _storage.write(
    key: _userKey,
    value: jsonEncode({
      'id': user.id,
      'nickname': user.nickname,
      'email': user.email,
      'iapAccountUuid': user.iapAccountUuid,
    }),
  );

  /// 로컬 로그인 정보만 지운다. 서버 데이터·로컬 학습기록은 그대로 유지.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// 구매를 "시작한" 계정의 토큰을 영구 저장(Keychain/Keystore)해둔다. 인앱결제 결과는
  /// 스토어에서 비동기로(앱이 완전히 꺼졌다 재시작된 뒤에도) 도착할 수 있는데, 그사이
  /// 로그아웃하거나 다른 계정으로 전환하면 "결제를 시작한 계정"이 아니라 "결과가 도착한
  /// 시점에 로그인된 계정"에 잘못 귀속될 수 있다. 메모리 변수로는 앱 재시작 시 사라져서
  /// 방지가 안 되므로, 로그인 토큰과 같은 보안 등급(secure storage)으로 영구 저장한다.
  /// 거래가 확정(성공/명시적 거부) 처리되면 [null]로 지운다.
  ///
  /// 알려진 한계: 슬롯이 1개뿐이라, 이전 구매가 아직 미해결(앱이 꺼진 채 대기 등)인
  /// 상태에서 다른 계정으로 새 구매를 또 시작하면 나중 값으로 덮어써진다 — 이 경우
  /// 먼저 시작한 구매가 재전달될 때 잘못된 계정으로 귀속될 수 있음(매우 드문 케이스,
  /// 항상 이용자 본인의 계정 중 하나로만 귀속되므로 피해는 제한적).
  Future<void> savePendingPurchaseToken(String? token) {
    if (token == null) return _storage.delete(key: _pendingIapTokenKey);
    return _storage.write(key: _pendingIapTokenKey, value: token);
  }

  Future<String?> get pendingPurchaseToken =>
      _storage.read(key: _pendingIapTokenKey);

  /// 회원탈퇴 — 서버 계정(클라우드 학습기록·구매 연결)을 삭제한다.
  /// 이 기기의 로컬 학습기록은 그대로 남는다(게스트로 계속 사용 가능).
  Future<void> deleteAccount() async {
    final token = await cachedToken;
    if (token == null) throw Exception('로그인이 필요해요');
    final res = await http.delete(
      Uri.parse('$_base/account'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('회원탈퇴 실패 (${res.statusCode})');
    }
    await logout();
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(secureStorageProvider)),
);
