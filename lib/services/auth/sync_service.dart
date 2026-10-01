import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_stats.dart';
import '../../state/app_state.dart';

/// 클라우드에 저장된 진도(학습기록+설정) 한 벌.
class CloudProgress {
  final UserStats? stats;
  final Settings? settings;

  /// 서버에 마지막으로 push된 시각(어느 기기든). 데이터가 없으면 null.
  final DateTime? updatedAt;

  const CloudProgress({this.stats, this.settings, this.updatedAt});

  bool get isEmpty => stats == null && settings == null;
}

/// 학습기록(UserStats)+설정(Settings) 동기화. 로그인 직후와 수동 "지금 동기화"에서만 호출됨
/// (앱 실행마다 자동 동기화하지 않음 — docs/소셜로그인_설정.md 방침).
class SyncService {
  static const _base = 'https://duo.jiny.shop/api/mathforadults';
  static const _lastSyncedAtKey = 'mfa_last_synced_at';

  final SharedPreferences _prefs;
  SyncService(this._prefs);

  DateTime? get lastSyncedAt {
    final raw = _prefs.getInt(_lastSyncedAtKey);
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  void _setLastSyncedAt(DateTime at) {
    _prefs.setInt(_lastSyncedAtKey, at.millisecondsSinceEpoch);
  }

  Future<CloudProgress> fetchCloud(String token) async {
    final res = await http
        .get(
          Uri.parse('$_base/progress'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('동기화 실패 (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final updatedAtRaw = body['updatedAt'] as String?;
    if (data == null) {
      return CloudProgress(
        updatedAt: updatedAtRaw != null
            ? DateTime.tryParse(updatedAtRaw)
            : null,
      );
    }
    final statsJson = data['stats'] as Map<String, dynamic>?;
    final settingsJson = data['settings'] as Map<String, dynamic>?;
    return CloudProgress(
      stats: statsJson != null ? UserStats.fromJson(statsJson) : null,
      settings: settingsJson != null ? Settings.fromJson(settingsJson) : null,
      updatedAt: updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null,
    );
  }

  Future<void> push(String token, UserStats stats, Settings settings) async {
    final res = await http
        .put(
          Uri.parse('$_base/progress'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'data': {'stats': stats.toJson(), 'settings': settings.toJson()},
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('업로드 실패 (${res.statusCode})');
    }
    _setLastSyncedAt(DateTime.now());
  }

  /// 로그인 직후 "충돌" 여부 — 이 기기와 계정(클라우드) 양쪽에 서로 다른 학습기록이
  /// 있을 때만 조용히 합치지 않고 사용자에게 먼저 물어본다.
  /// 한쪽이 비어 있으면(신규 계정/새 기기) 그냥 가져오거나 올리고, 풀었던 문제 집합이
  /// 완전히 같으면(이미 동기화된 적 있어서 일치) "다른 기록"이 아니므로 묻지 않는다.
  bool hasConflict(CloudProgress cloud, UserStats localStats) {
    final cloudStats = cloud.stats;
    if (cloudStats == null) return false;
    if (localStats.totalSolved == 0 || cloudStats.totalSolved == 0) {
      return false;
    }
    return !_sameSolvedIds(localStats, cloudStats);
  }

  bool _sameSolvedIds(UserStats a, UserStats b) =>
      a.solvedIds.length == b.solvedIds.length &&
      a.solvedIds.containsAll(b.solvedIds);

  /// 클라우드와 로컬을 병합한 결과.
  /// - UserStats: 항상 [UserStats.mergedWith]로 누적 병합(순서 무관하게 안전).
  /// - Settings: 마지막 동기화 시각 기준 last-write-wins.
  ///   내가 모르는 사이 다른 기기가 더 최근에 올렸으면(cloud.updatedAt > 내 lastSyncedAt)
  ///   클라우드 설정을 채택하고, 그 외엔 로컬 설정을 유지한다.
  ({UserStats stats, Settings settings}) merge(
    CloudProgress cloud,
    UserStats localStats,
    Settings localSettings,
  ) {
    final mergedStats = cloud.stats != null
        ? localStats.mergedWith(cloud.stats!)
        : localStats;
    final mine = lastSyncedAt;
    final cloudIsNewer =
        cloud.updatedAt != null &&
        (mine == null || cloud.updatedAt!.isAfter(mine));
    final mergedSettings = (cloudIsNewer && cloud.settings != null)
        ? cloud.settings!
        : localSettings;
    return (stats: mergedStats, settings: mergedSettings);
  }
}

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(sharedPreferencesProvider)),
);
