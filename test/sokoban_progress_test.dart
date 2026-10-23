import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_for_adults/services/usage_events.dart';
import 'package:math_for_adults/screens/game/sokoban_levels.dart';
import 'package:math_for_adults/screens/game/sokoban_logic.dart';
import 'package:math_for_adults/screens/game/sokoban_screen.dart';
import 'package:math_for_adults/screens/game/sokoban_store.dart';
import 'package:math_for_adults/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  return SharedPreferences.getInstance();
}

Widget _app(SharedPreferences prefs, Widget home) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: MaterialApp(home: home),
);

void main() {
  test('경로를 저장했다가 되감으면 같은 판이 복원된다', () {
    final l = sokobanLevels[3];
    final a = SokobanGame(l);
    for (final ch
        in l.solution.substring(0, l.solution.length ~/ 2).split('')) {
      const d = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
      a.move(d[ch]!.$1, d[ch]!.$2);
    }
    a.undo();
    final b = SokobanGame(l);
    expect(b.restore(a.path, a.moves), isTrue);
    expect(b.player, a.player);
    expect([for (final x in b.boxes) x.pos], [for (final x in a.boxes) x.pos]);
    expect(b.moves, a.moves);
    expect(b.pushes, a.pushes);
    expect(b.path, a.path);
  });

  test('잘못된 경로는 복원하지 않고 처음 상태로 둔다', () {
    final g = SokobanGame(sokobanLevels[0]);
    expect(g.restore('UUUUUUUUUUUU', 12), isFalse);
    expect(g.moves, 0);
    expect(g.path, '');
  });

  test('저장소: 단계별 저장', () async {
    final s = SokobanStore(await _prefs());
    await s.save(4, const SokobanSave('RR', 2, 12.5));
    final back = SokobanStore(await SharedPreferences.getInstance());
    expect(back.load(4)!.path, 'RR');
    expect(back.load(4)!.timeLeft, 12.5);
    expect(back.savedLevels, {4});
    await back.clear(4);
    expect(back.load(4), isNull);
  });

  testWidgets('나갔다 들어와도 진행 중인 판이 이어진다', (t) async {
    final prefs = await _prefs();
    final l = sokobanLevels[0];
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    final first = l.solution[0];
    final state = t.state<State>(find.byType(SokobanPlayScreen));
    expect(state, isNotNull);
    // 화면을 바꿔 끼워 dispose 시 저장되는지 확인
    final g = SokobanGame(l)
      ..move(
        first == 'U'
            ? -1
            : first == 'D'
            ? 1
            : 0,
        first == 'L'
            ? -1
            : first == 'R'
            ? 1
            : 0,
      );
    await SokobanStore(prefs).save(0, SokobanSave(g.path, g.moves, null));
    await t.pumpWidget(_app(prefs, const SizedBox()));
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    expect(find.text('👣 1걸음'), findsOneWidget);
  });

  /// 첫 걸음만 걸어 둔 저장을 만든다.
  Future<SharedPreferences> withFirstStep() async {
    final prefs = await _prefs();
    final g = SokobanGame(sokobanLevels[0]);
    const d = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
    final c = sokobanLevels[0].solution[0];
    g.move(d[c]!.$1, d[c]!.$2);
    await SokobanStore(prefs).save(0, SokobanSave(g.path, g.moves, null));
    return prefs;
  }

  testWidgets('새로고침: 진행했으면 확인 후 처음으로 돌아가고 저장이 지워진다', (t) async {
    final prefs = await withFirstStep();
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    expect(find.text('👣 1걸음'), findsOneWidget);
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('다시 할까요'), findsOneWidget);
    await t.tap(find.text('다시 하기'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('👣 0걸음'), findsOneWidget);
    expect(SokobanStore(prefs).load(0), isNull);
  });

  testWidgets('새로고침 확인창에서 취소하면 그대로다', (t) async {
    final prefs = await withFirstStep();
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('취소'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('👣 1걸음'), findsOneWidget);
    expect(SokobanStore(prefs).load(0), isNotNull);
  });

  testWidgets('한 걸음도 안 움직였으면 확인 없이 바로 다시 시작', (t) async {
    final prefs = await _prefs();
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('다시 할까요'), findsNothing);
    expect(find.text('👣 0걸음'), findsOneWidget);
  });

  testWidgets('클리어하면 저장이 지워진다', (t) async {
    final prefs = await _prefs();
    final l = sokobanLevels[0];
    const d = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
    final g = SokobanGame(l);
    for (final ch in l.solution.substring(0, l.solution.length - 1).split('')) {
      g.move(d[ch]!.$1, d[ch]!.$2);
    }
    await SokobanStore(prefs).save(0, SokobanSave(g.path, g.moves, null));
    await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
    await t.pump();
    final k = l.solution[l.solution.length - 1];
    final arrow = {
      'U': Icons.keyboard_arrow_up_rounded,
      'D': Icons.keyboard_arrow_down_rounded,
      'L': Icons.keyboard_arrow_left_rounded,
      'R': Icons.keyboard_arrow_right_rounded,
    }[k]!;
    await t.tap(find.byIcon(arrow).first);
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('클리어'), findsOneWidget);
    expect(SokobanStore(prefs).load(0), isNull);
  });

  group('사용 이벤트', () {
    /// 이벤트를 켠 채 서버로 나간 이벤트 이름을 모은다.
    Future<List<String>> capture(
      SharedPreferences prefs,
      Future<void> Function() body,
    ) async {
      final sent = <Map<String, dynamic>>[];
      await UsageEvents.instance.init(
        prefs,
        deviceId: () => 'dev',
        enabled: true,
        client: MockClient((req) async {
          sent.addAll(
            ((jsonDecode(req.body) as Map)['events'] as List)
                .cast<Map<String, dynamic>>(),
          );
          return http.Response('{}', 200);
        }),
      );
      await body();
      await UsageEvents.instance.flush();
      return [
        for (final e in sent)
          '${e['e']}:${e['level'] ?? ''}:${e['value'] ?? ''}:${e['extra'] ?? ''}',
      ];
    }

    testWidgets('새로 들어가면 sk_start, 저장된 판이면 sk_resume', (t) async {
      final fresh = await _prefs();
      final a = await capture(fresh, () async {
        await t.pumpWidget(_app(fresh, SokobanPlayScreen(level: 0)));
        await t.pump();
      });
      expect(a, ['sk_start:1::']);

      final saved = await withFirstStep();
      final b = await capture(saved, () async {
        await t.pumpWidget(const SizedBox()); // 이전 화면을 없애야 initState 가 다시 돈다
        await t.pumpWidget(_app(saved, SokobanPlayScreen(level: 0)));
        await t.pump();
      });
      expect(b, ['sk_resume:1::']);
    });

    testWidgets('마지막 한 걸음으로 클리어하면 sk_clear(걸음·별)', (t) async {
      final prefs = await _prefs();
      const idx = 3; // 풀이가 3걸음 이상인 단계
      final l = sokobanLevels[idx];
      expect(l.solution.length, greaterThan(2));
      const d = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
      final g = SokobanGame(l);
      for (final ch
          in l.solution.substring(0, l.solution.length - 1).split('')) {
        g.move(d[ch]!.$1, d[ch]!.$2);
      }
      await SokobanStore(prefs).save(idx, SokobanSave(g.path, g.moves, null));
      final k = l.solution[l.solution.length - 1];
      final arrow = {
        'U': Icons.keyboard_arrow_up_rounded,
        'D': Icons.keyboard_arrow_down_rounded,
        'L': Icons.keyboard_arrow_left_rounded,
        'R': Icons.keyboard_arrow_right_rounded,
      }[k]!;
      final ev = await capture(prefs, () async {
        await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: idx)));
        await t.pump();
        await t.tap(find.byIcon(arrow).first);
        await t.pump(const Duration(seconds: 1));
      });
      expect(ev.first, 'sk_resume:${idx + 1}::');
      expect(ev.last, 'sk_clear:${idx + 1}:${l.par}:3');
    });

    testWidgets('새로하기를 확인하면 sk_restart(걸음) 뒤 sk_start', (t) async {
      final prefs = await withFirstStep();
      final ev = await capture(prefs, () async {
        await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
        await t.pump();
        await t.tap(find.byIcon(Icons.refresh_rounded));
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.text('다시 하기'));
        await t.pump(const Duration(milliseconds: 400));
      });
      expect(ev, ['sk_resume:1::', 'sk_restart:1:1:', 'sk_start:1::']);
    });

    testWidgets('움직이기 전 새로고침은 새 시도로 세지 않는다', (t) async {
      final prefs = await _prefs();
      final ev = await capture(prefs, () async {
        await t.pumpWidget(_app(prefs, SokobanPlayScreen(level: 0)));
        await t.pump();
        await t.tap(find.byIcon(Icons.refresh_rounded));
        await t.pump(const Duration(milliseconds: 400));
      });
      expect(ev, ['sk_start:1::']);
    });
  });
}
