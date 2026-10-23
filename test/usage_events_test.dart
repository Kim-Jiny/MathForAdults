import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_for_adults/services/usage_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs([Map<String, Object> init = const {}]) async {
    SharedPreferences.setMockInitialValues(init);
    return SharedPreferences.getInstance();
  }

  test('디버그 기본값에서는 아무것도 보내지 않는다', () async {
    var calls = 0;
    final ev = UsageEvents.instance;
    await ev.init(
      await prefs(),
      deviceId: () => 'dev',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    ev.log('sk_start', level: 1);
    await ev.flush();
    expect(calls, 0);
    expect(ev.pending, 0);
  });

  test('모아서 보내고, 서버 형식(ago·필드)에 맞게 직렬화한다', () async {
    final bodies = <Map<String, dynamic>>[];
    final ev = UsageEvents.instance;
    await ev.init(
      await prefs(),
      deviceId: () => 'dev-1',
      enabled: true,
      client: MockClient((req) async {
        expect(req.url.path, '/api/mathforadults/events');
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('{"success":true}', 200);
      }),
    );
    ev.log('sk_start', level: 3);
    ev.log('sk_clear', level: 3, value: 21, extra: '3');
    ev.log('ad_shown', extra: 'restart');
    expect(ev.pending, 3);
    await ev.flush();
    expect(ev.pending, 0);
    expect(bodies, hasLength(1));
    expect(bodies[0]['deviceId'], 'dev-1');
    final events = (bodies[0]['events'] as List).cast<Map<String, dynamic>>();
    expect(events.map((e) => e['e']), ['sk_start', 'sk_clear', 'ad_shown']);
    expect(events[1], containsPair('value', 21));
    expect(events[1], containsPair('extra', '3'));
    expect(events[2].containsKey('level'), isFalse);
    expect(events.every((e) => !e.containsKey('t') && e['ago'] is int), isTrue);
  });

  test('전송 실패 시 큐에 남기고 다음에 다시 보낸다', () async {
    var ok = false;
    final ev = UsageEvents.instance;
    await ev.init(
      await prefs(),
      deviceId: () => 'dev',
      enabled: true,
      client: MockClient(
        (_) async => ok ? http.Response('{}', 200) : http.Response('boom', 500),
      ),
    );
    ev.log('sk_start', level: 1);
    await ev.flush();
    expect(ev.pending, 1);
    ok = true;
    await ev.flush();
    expect(ev.pending, 0);
  });

  test('앱을 껐다 켜도 못 보낸 이벤트가 남아 있다', () async {
    final p = await prefs();
    final ev = UsageEvents.instance;
    await ev.init(
      p,
      deviceId: () => 'dev',
      enabled: true,
      client: MockClient((_) async => http.Response('boom', 500)),
    );
    ev.log('sk_fail', level: 8, extra: 'steps');
    await ev.flush();
    expect(ev.pending, 1);
    // 재시작: 같은 저장소로 다시 init
    var sent = 0;
    await ev.init(
      p,
      deviceId: () => 'dev',
      enabled: true,
      client: MockClient((req) async {
        sent = (jsonDecode(req.body)['events'] as List).length;
        return http.Response('{}', 200);
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sent, 1);
    expect(ev.pending, 0);
  });

  test('큐가 200개를 넘으면 오래된 것부터 버리고, 50개씩 나눠 보낸다', () async {
    final sizes = <int>[];
    final ev = UsageEvents.instance;
    await ev.init(
      await prefs(),
      deviceId: () => 'dev',
      enabled: true,
      client: MockClient((req) async {
        sizes.add((jsonDecode(req.body)['events'] as List).length);
        return http.Response('{}', 200);
      }),
    );
    // flush 임계값(10)에서 자동 전송되지 않도록 실패 응답 상태로 쌓는다.
    final failing = MockClient((_) async => http.Response('boom', 500));
    await ev.init(
      await prefs(),
      deviceId: () => 'dev',
      enabled: true,
      client: failing,
    );
    for (var i = 0; i < 230; i++) {
      ev.log('sk_start', level: 1);
    }
    await ev.flush();
    expect(ev.pending, 200);
    // 임계값 때문에 await 없이 시작된 전송이 끝나길 기다린다.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await ev.init(
      await prefs({
        'mfa_event_queue_v1': jsonEncode(
          List.generate(
            120,
            (i) => {
              'e': 'sk_start',
              'level': 1,
              't': DateTime.now().millisecondsSinceEpoch,
            },
          ),
        ),
      }),
      deviceId: () => 'dev',
      enabled: true,
      client: MockClient((req) async {
        sizes.add((jsonDecode(req.body)['events'] as List).length);
        return http.Response('{}', 200);
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sizes, [50, 50, 20]);
    expect(ev.pending, 0);
  });
}
