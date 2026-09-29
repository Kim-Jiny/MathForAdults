import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_stats.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/sync_service.dart';
import 'app_state.dart';

enum ConflictChoice { merge, useCloud, cancel }

/// 로그인 직후 이 기기와 계정(클라우드) 양쪽에 서로 다른 학습기록이 있을 때,
/// 사용자가 고를 때까지 들고 있는 스냅샷.
class ProgressConflict {
  final UserStats localStats;
  final UserStats cloudStats;
  final Settings localSettings;
  final Settings? cloudSettings;

  const ProgressConflict({
    required this.localStats,
    required this.cloudStats,
    required this.localSettings,
    required this.cloudSettings,
  });
}

class AuthState {
  final AuthUser? user;
  final bool syncing;
  final String? error;
  final DateTime? lastSyncedAt;
  final ProgressConflict? conflict;

  const AuthState({
    this.user,
    this.syncing = false,
    this.error,
    this.lastSyncedAt,
    this.conflict,
  });

  bool get loggedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? syncing,
    String? error,
    bool clearError = false,
    DateTime? lastSyncedAt,
    ProgressConflict? conflict,
    bool clearConflict = false,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    syncing: syncing ?? this.syncing,
    error: clearError ? null : (error ?? this.error),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    conflict: clearConflict ? null : (conflict ?? this.conflict),
  );
}

/// 로그인 상태 + 로그인 직후/수동 동기화 오케스트레이션.
/// 학습기록·설정 자체의 소스는 여전히 [statsProvider]/[settingsProvider] —
/// 여긴 로그인 여부와 "지금 클라우드와 합치기" 동작만 담당한다.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _auth;
  final SyncService _sync;
  final Ref _ref;

  AuthNotifier(this._auth, this._sync, this._ref) : super(const AuthState()) {
    _restore();
  }

  Future<void> _restore() async {
    final user = await _auth.cachedUser;
    if (user != null) {
      state = state.copyWith(user: user, lastSyncedAt: _sync.lastSyncedAt);
    }
  }

  Future<void> loginWithGoogle() => _guardLogin(_auth.loginWithGoogle);
  Future<void> loginWithApple() => _guardLogin(_auth.loginWithApple);
  Future<void> loginWithKakao() => _guardLogin(_auth.loginWithKakao);

  Future<void> _guardLogin(Future<AuthUser> Function() login) async {
    state = state.copyWith(syncing: true, clearError: true);
    final AuthUser user;
    try {
      user = await login();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 로그인 실패: $e');
      state = state.copyWith(syncing: false, error: '로그인에 실패했어요');
      return;
    }
    // 로그인은 성공 — 최초 동기화(또는 충돌 확인)가 실패해도 로그인 상태는 유지한다.
    state = state.copyWith(user: user);
    try {
      final token = await _auth.cachedToken;
      if (token == null) {
        await logout();
        return;
      }
      final cloud = await _sync.fetchCloud(token);
      final localStats = _ref.read(statsProvider);
      final localSettings = _ref.read(settingsProvider);

      if (_sync.hasConflict(cloud, localStats)) {
        // 이 기기와 계정 양쪽에 진짜 기록이 있음 — 조용히 합치지 않고 사용자에게 물어본다.
        state = state.copyWith(
          conflict: ProgressConflict(
            localStats: localStats,
            cloudStats: cloud.stats!,
            localSettings: localSettings,
            cloudSettings: cloud.settings,
          ),
        );
        return;
      }
      await _applyMergeAndPush(token, cloud, localStats, localSettings);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 최초 동기화 실패: $e');
      state = state.copyWith(error: '동기화에 실패했어요');
    } finally {
      // 충돌 다이얼로그를 띄운 경우엔 사용자가 고를 때까지 syncing 스피너를 유지한다.
      if (state.conflict == null) state = state.copyWith(syncing: false);
    }
  }

  /// 충돌 다이얼로그에서 사용자가 고른 결과 반영.
  Future<void> resolveConflict(ConflictChoice choice) async {
    final conflict = state.conflict;
    if (conflict == null) return;
    state = state.copyWith(clearConflict: true);

    if (choice == ConflictChoice.cancel) {
      await logout();
      return;
    }

    state = state.copyWith(syncing: true, clearError: true);
    try {
      final token = await _auth.cachedToken;
      if (token == null) {
        await logout();
        return;
      }
      final finalStats = choice == ConflictChoice.merge
          ? conflict.localStats.mergedWith(conflict.cloudStats)
          : conflict.cloudStats;
      final finalSettings = choice == ConflictChoice.merge
          ? conflict.localSettings
          : (conflict.cloudSettings ?? conflict.localSettings);
      await _sync.push(token, finalStats, finalSettings);
      _ref.read(statsProvider.notifier).replaceAll(finalStats);
      _ref.read(settingsProvider.notifier).replaceAll(finalSettings);
      state = state.copyWith(lastSyncedAt: _sync.lastSyncedAt);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 충돌 해결 실패: $e');
      state = state.copyWith(error: '동기화에 실패했어요');
    } finally {
      state = state.copyWith(syncing: false);
    }
  }

  /// 로그인된 상태에서 수동 "지금 동기화". (충돌 다이얼로그 없이 항상 합침 — 이미 로그인된
  /// 기기끼리의 정상적인 누적 동기화라 로그인 시점의 "낯선 계정" 상황과는 다르다.)
  Future<void> syncNow() async {
    if (!state.loggedIn) return;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final token = await _auth.cachedToken;
      if (token == null) {
        await logout();
        return;
      }
      final cloud = await _sync.fetchCloud(token);
      final localStats = _ref.read(statsProvider);
      final localSettings = _ref.read(settingsProvider);
      await _applyMergeAndPush(token, cloud, localStats, localSettings);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 동기화 실패: $e');
      if (e.toString().contains('401')) {
        await logout();
      } else {
        state = state.copyWith(error: '동기화에 실패했어요');
      }
    } finally {
      state = state.copyWith(syncing: false);
    }
  }

  Future<void> _applyMergeAndPush(
    String token,
    CloudProgress cloud,
    UserStats localStats,
    Settings localSettings,
  ) async {
    final merged = _sync.merge(cloud, localStats, localSettings);
    await _sync.push(token, merged.stats, merged.settings);
    _ref.read(statsProvider.notifier).replaceAll(merged.stats);
    _ref.read(settingsProvider.notifier).replaceAll(merged.settings);
    state = state.copyWith(lastSyncedAt: _sync.lastSyncedAt);
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const AuthState();
  }

  Future<bool> updateNickname(String nickname) async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final user = await _auth.updateNickname(nickname);
      state = state.copyWith(user: user, syncing: false);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] 닉네임 변경 실패: $e');
      state = state.copyWith(syncing: false, error: '닉네임 변경에 실패했어요');
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(syncServiceProvider),
    ref,
  );
});
