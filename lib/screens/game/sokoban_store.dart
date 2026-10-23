import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 진행 중인 판 하나: 지금까지의 걸음 방향과 (되돌리기까지 센) 걸음 수, 폭탄 남은 시간.
class SokobanSave {
  final String path;
  final int moves;
  final double? timeLeft;
  const SokobanSave(this.path, this.moves, this.timeLeft);
}

/// 단계별로 진행 중인 판을 기기에 저장한다.
class SokobanStore {
  static const _kSaves = 'sokoban_save_v1';

  final SharedPreferences _prefs;
  const SokobanStore(this._prefs);

  Map<String, dynamic> _readAll() {
    try {
      final raw = _prefs.getString(_kSaves);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  SokobanSave? load(int level) {
    final m = _readAll()['$level'];
    if (m is! Map) return null;
    final path = m['p'];
    final moves = m['m'];
    final t = m['t'];
    if (path is! String || path.isEmpty || moves is! int) return null;
    return SokobanSave(path, moves, t is num ? t.toDouble() : null);
  }

  /// 진행 중인 판이 있는 단계 번호(0부터).
  Set<int> get savedLevels => {
    for (final k in _readAll().keys)
      if (int.tryParse(k) != null && load(int.parse(k)) != null) int.parse(k),
  };

  Future<void> save(int level, SokobanSave s) {
    final all = _readAll();
    all['$level'] = {'p': s.path, 'm': s.moves, 't': ?s.timeLeft};
    return _prefs.setString(_kSaves, jsonEncode(all));
  }

  Future<void> clear(int level) {
    final all = _readAll();
    if (all.remove('$level') == null) return Future.value();
    return _prefs.setString(_kSaves, jsonEncode(all));
  }
}
