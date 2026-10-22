import 'package:flutter_test/flutter_test.dart';
import 'package:math_for_adults/screens/game/sokoban_levels.dart';
import 'package:math_for_adults/screens/game/sokoban_logic.dart';

/// 생성기(tool/gen_sokoban.py)가 저장한 풀이를 게임 규칙으로 그대로 재생해
/// 파이썬 풀이기와 게임 로직이 같은 규칙을 쓰는지, 모든 단계가 풀리는지 확인한다.
void main() {
  test('100단계', () => expect(sokobanLevels.length, 100));

  for (var i = 0; i < sokobanLevels.length; i++) {
    final l = sokobanLevels[i];
    test('${i + 1}단계 풀이 재생: ${l.name}', () {
      final g = SokobanGame(l);
      const dirs = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
      for (final ch in l.solution.split('')) {
        final d = dirs[ch]!;
        final res = g.move(d.$1, d.$2);
        expect(
          res == MoveResult.moved || res == MoveResult.pushed,
          isTrue,
          reason: '$ch 에서 $res',
        );
      }
      expect(g.solved, isTrue);
      expect(g.moves, l.par);
      if (l.limit != null) expect(l.limit! >= l.par, isTrue);
    });
  }
}
