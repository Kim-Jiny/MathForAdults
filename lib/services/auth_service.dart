import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config.dart';
import '../models/user_stats.dart';
import '../state/app_state.dart';

/// 로그인 계정 (선택적). 토큰은 클라우드 동기화에 사용.
class Account {
  final int id;
  final String? email;
  final String? nickname;
  final String token;

  const Account({required this.id, this.email, this.nickname, required this.token});

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'nickname': nickname, 'token': token};

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as int,
        email: j['email'] as String?,
        nickname: j['nickname'] as String?,
        token: j['token'] as String,
      );
}

/// 동기화 진행 상태(UI 표시용).
enum SyncPhase { idle, working, done, error }

class AccountState {
  final Account? account;
  final SyncPhase phase;
  final String? message;

  const AccountState({this.account, this.phase = SyncPhase.idle, this.message});

  bool get loggedIn => account != null;

  AccountState copyWith({Account? account, bool clearAccount = false, SyncPhase? phase, String? message}) =>
      AccountState(
        account: clearAccount ? null : (account ?? this.account),
        phase: phase ?? this.phase,
        message: message,
      );
}

class AccountNotifier extends StateNotifier<AccountState> {
  final Ref _ref;
  final SharedPreferences _prefs;
  static const _key = 'mfa_account';

  AccountNotifier(this._ref, this._prefs) : super(const AccountState()) {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        state = AccountState(account: Account.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
  }

  void _save(Account? a) {
    if (a == null) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, jsonEncode(a.toJson()));
    }
  }

  // ── 소셜 로그인 ──────────────────────────────────────────
  Future<void> signInWithGoogle() => _login(() async {
        final google = GoogleSignIn(
          serverClientId: AppConfig.googleServerClientId.isEmpty
              ? null
              : AppConfig.googleServerClientId,
          scopes: const ['email'],
        );
        final acc = await google.signIn();
        if (acc == null) return null; // 사용자 취소
        final auth = await acc.authentication;
        return ('google', auth.idToken);
      });

  Future<void> signInWithApple() => _login(() async {
        final cred = await SignInWithApple.getAppleIDCredential(scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ]);
        return ('apple', cred.identityToken);
      });

  Future<void> _login(Future<(String, String?)?> Function() getToken) async {
    state = state.copyWith(phase: SyncPhase.working);
    try {
      final res = await getToken();
      if (res == null) {
        state = state.copyWith(phase: SyncPhase.idle); // 취소
        return;
      }
      final (provider, idToken) = res;
      if (idToken == null) throw Exception('소셜 토큰을 받지 못했어요');

      final r = await http
          .post(Uri.parse('${AppConfig.apiBase}/auth/social'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'provider': provider, 'idToken': idToken}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('로그인 실패 (${r.statusCode})');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final u = data['user'] as Map<String, dynamic>;
      final account = Account(
        id: u['id'] as int,
        email: u['email'] as String?,
        nickname: u['nickname'] as String?,
        token: data['token'] as String,
      );
      _save(account);
      state = AccountState(account: account, phase: SyncPhase.working);
      await _syncMerge(account); // 로그인 직후 병합 동기화
      state = state.copyWith(phase: SyncPhase.done, message: '로그인 완료');
    } catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: '로그인에 실패했어요');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    _save(null);
    state = const AccountState();
  }

  // ── 동기화 ───────────────────────────────────────────────
  /// 수동 동기화: 로컬과 클라우드 병합 후 업로드.
  Future<void> syncNow() async {
    final a = state.account;
    if (a == null) return;
    state = state.copyWith(phase: SyncPhase.working);
    try {
      await _syncMerge(a);
      state = state.copyWith(phase: SyncPhase.done, message: '동기화 완료');
    } catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: '동기화에 실패했어요');
    }
  }

  Future<void> _syncMerge(Account a) async {
    final remote = await _download(a.token);
    final local = _ref.read(statsProvider);
    final merged = remote == null ? local : local.mergedWith(remote);
    _ref.read(statsProvider.notifier).replaceAll(merged);
    await _upload(a.token, merged);
  }

  Future<UserStats?> _download(String token) async {
    final r = await http.get(Uri.parse('${AppConfig.apiBase}/progress'),
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('동기화 실패 (${r.statusCode})');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (data['data'] == null) return null;
    return UserStats.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> _upload(String token, UserStats stats) async {
    final r = await http
        .put(Uri.parse('${AppConfig.apiBase}/progress'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'data': stats.toJson()}))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('업로드 실패 (${r.statusCode})');
  }
}

final accountProvider = StateNotifierProvider<AccountNotifier, AccountState>(
  (ref) => AccountNotifier(ref, ref.watch(sharedPreferencesProvider)),
);
