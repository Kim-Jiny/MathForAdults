import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 학습 리마인더. 서버 없이 기기에서 매일 지정 시각에 알림.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static const _dailyId = 1001;

  static Future<void> init() async {
    if (_inited) return;
    try {
      tzdata.initializeTimeZones();
      // 한국 대상 앱 — 기본 표준시 Asia/Seoul.
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      _inited = true;
    } catch (_) {
      // 플러그인 미등록(핫리스타트 직후/웹 등)이라도 앱 시작은 막지 않는다.
    }
  }

  /// 알림 권한 요청. 허용 여부 반환.
  static Future<bool> requestPermission() async {
    try {
      await init();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 매일 [hour]:[minute]에 반복 알림 예약 (기존 예약은 교체).
  static Future<void> scheduleDaily(int hour, int minute) async {
    try {
      await init();
      await _plugin.cancel(_dailyId);

      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        _dailyId,
        '오늘의 한 문제',
        '잠깐, 수학 한 문제 풀고 갈까요?',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            '학습 리마인더',
            channelDescription: '매일 학습 알림',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시각 반복
      );
    } catch (_) {
      // 예약 실패해도 앱 흐름엔 영향 없음.
    }
  }

  static Future<void> cancelDaily() async {
    try {
      await init();
      await _plugin.cancel(_dailyId);
    } catch (_) {}
  }
}
