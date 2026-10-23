import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 익명 사용 이벤트(소코반 단계 진행·전면 광고 노출)를 모아 서버로 보낸다.
///
/// 관리자 페이지의 소코반·광고 지표용이고 개인정보는 없다 — deviceId(앱이 만든 임의 문자열)와
/// 이벤트 이름·단계·걸음 수만 보낸다. 전송에 실패해도 앱 기능엔 영향이 없고,
/// 못 보낸 이벤트는 기기에 남겨 다음에 다시 보낸다.
/// 개발 중 누른 기록이 운영 통계를 오염시키지 않도록 디버그 빌드에서는 아무것도 하지 않는다.
class UsageEvents with WidgetsBindingObserver {
  UsageEvents._();
  static final UsageEvents instance = UsageEvents._();

  static const _base = 'https://duo.jiny.shop/api/mathforadults';
  static const _kQueueKey = 'mfa_event_queue_v1';
  static const _batch = 50; // 서버가 한 번에 받는 최대 개수
  static const _maxQueue = 200; // 오래 오프라인이어도 무한히 쌓지 않는다
  static const _flushThreshold = 10;
  static const _flushDelay = Duration(seconds: 20);

  SharedPreferences? _prefs;
  String Function()? _deviceId;
  http.Client _client = http.Client();
  bool _enabled = false;
  bool _sending = false;
  Timer? _timer;
  final List<Map<String, Object>> _queue = [];

  /// main()에서 1회 호출. [enabled] 기본값은 릴리스 빌드에서만 true.
  Future<void> init(
    SharedPreferences prefs, {
    required String Function() deviceId,
    @visibleForTesting http.Client? client,
    @visibleForTesting bool? enabled,
  }) async {
    _enabled = enabled ?? !kDebugMode;
    if (!_enabled) return;
    _prefs = prefs;
    _deviceId = deviceId;
    if (client != null) _client = client;
    _queue
      ..clear()
      ..addAll(_load(prefs));
    WidgetsBinding.instance.addObserver(this);
    if (_queue.isNotEmpty) flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드로 가면 남은 이벤트를 서둘러 보낸다.
    if (state == AppLifecycleState.paused) flush();
  }

  /// 이벤트 하나를 기록한다. [e]는 서버가 허용하는 이름이어야 한다.
  void log(String e, {int? level, int? value, String? extra}) {
    if (!_enabled || _prefs == null) return;
    _queue.add({
      'e': e,
      'level': ?level,
      'value': ?value,
      'extra': ?extra,
      't': DateTime.now().millisecondsSinceEpoch,
    });
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    _save();
    if (_queue.length >= _flushThreshold) {
      flush();
    } else {
      _timer ??= Timer(_flushDelay, () {
        _timer = null;
        flush();
      });
    }
  }

  /// 쌓인 이벤트를 서버로 보낸다. 실패하면 큐에 그대로 남는다.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!_enabled || _sending || _queue.isEmpty) return;
    _sending = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sent = _queue.take(_batch).toList();
      final res = await _client
          .post(
            Uri.parse('$_base/events'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'deviceId': _deviceId!(),
              'platform': Platform.isIOS ? 'ios' : 'android',
              'events': [
                for (final ev in sent)
                  {
                    for (final k in ev.keys)
                      if (k != 't') k: ev[k],
                    'ago': ((now - (ev['t'] as int)) / 1000).round(),
                  },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _queue.removeRange(0, sent.length);
        _save();
        if (_queue.isNotEmpty) {
          _sending = false;
          await flush();
        }
      }
    } catch (_) {
      // 통계용 — 실패하면 다음 기회에 다시 보낸다.
    } finally {
      _sending = false;
    }
  }

  int get pending => _queue.length;

  void _save() {
    _prefs?.setString(_kQueueKey, jsonEncode(_queue));
  }

  static List<Map<String, Object>> _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kQueueKey);
      if (raw == null) return [];
      return [
        for (final m in jsonDecode(raw) as List)
          if (m is Map && m['e'] is String && m['t'] is int)
            Map<String, Object>.from(m.cast<String, Object>()),
      ];
    } catch (_) {
      return [];
    }
  }
}
