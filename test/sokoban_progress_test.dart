import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
