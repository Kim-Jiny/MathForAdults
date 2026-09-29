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

  const AuthUser({required this.id, this.nickname, this.email});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as int,
    nickname: j['nickname'] as String?,
    email: j['email'] as String?,
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
    }),
  );

  /// 로컬 로그인 정보만 지운다. 서버 데이터·로컬 학습기록은 그대로 유지.
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

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
