/// 소코반 규칙: 선물상자를 밀어 모든 꽃자리를 채우면 클리어.
///
/// 단계가 오르면 규칙이 하나씩 늘어난다.
///  - 걸음 제한([SokobanLevel.limit]): 되돌리기도 1걸음으로 센다.
///  - 순서: 숫자 꽃은 1번부터 차례로 채워야 다음 꽃에 놓을 수 있다.
///  - 색 맞추기: 색 상자는 같은 색 꽃자리에 놓아야 "찬" 것으로 친다.
///  - 잠금([SokobanLevel.lock]): 제자리에 놓은 상자는 잠겨서 더는 밀 수 없다.
///  - 폭탄([SokobanLevel.seconds]): 제한 시간 안에 끝내야 한다.
class SokobanLevel {
  final String name;

  /// # 벽  . 목표  1~9 순서 목표  a~d 색 목표  $ 상자  A~D 색 상자
  /// * 목표 위 상자  @ 플레이어  + 목표 위 플레이어
  final List<String> rows;
  final int par; // 최단 걸음
  final int? limit; // 걸음 제한
  final int? seconds; // 폭탄 제한 시간
  final bool lock;
  final String solution; // U/D/L/R — 테스트에서 재생해 풀림을 검증한다

  const SokobanLevel(
    this.name,
    this.rows, {
    required this.par,
    this.limit,
    this.seconds,
    this.lock = false,
    required this.solution,
  });

  bool get ordered => rows.any((r) => RegExp(r'[1-9]').hasMatch(r));
  bool get colored => rows.any((r) => RegExp(r'[a-dA-D]').hasMatch(r));

  /// 이 단계에 적용되는 규칙.
  Set<SokobanRule> get rules => {
    if (limit != null) SokobanRule.steps,
    if (ordered) SokobanRule.order,
    if (colored) SokobanRule.color,
    if (lock) SokobanRule.lock,
    if (seconds != null) SokobanRule.bomb,
  };

  /// 별 개수: 최단에 가까울수록 3개.
  int starsFor(int moves) {
    if (moves <= (par * 1.2).ceil() + 2) return 3;
    if (moves <= (par * 1.6).ceil() + 4) return 2;
    return 1;
  }
}

enum SokobanRule { steps, order, color, lock, bomb }

typedef Pos = (int r, int c);

class Box {
  final int id; // 애니메이션 키 — 이동해도 유지된다
  final Pos pos;
  final int color; // 0 = 보통, 1~4 = 색 상자
  const Box(this.id, this.pos, [this.color = 0]);
}

class _Snapshot {
  final Pos player;
  final List<Box> boxes;
  final int moves;
  final int pushes;
  final String dir; // 이 스냅샷 다음에 한 걸음의 방향(U/D/L/R)
  _Snapshot(this.player, this.boxes, this.moves, this.pushes, this.dir);
}

enum MoveResult {
  blocked, // 벽이나 다른 상자에 막힘
  moved,
  pushed,
  orderBlocked, // 앞 번호 꽃이 아직 비어 있음
  locked, // 이미 잠긴 상자
}

class SokobanGame {
  final SokobanLevel level;
  late final int rows;
  late final int cols;
  final Set<Pos> walls = {};
  final Map<Pos, int> goalOrder = {}; // 목표 칸 -> 순서(0 = 순서 없음)
  final Map<Pos, int> goalColor = {}; // 목표 칸 -> 색(0 = 아무 상자나)
  final Set<Pos> floor = {}; // 바깥 공간을 제외한 실내 칸
  late final Pos _startPlayer;
  late final List<Box> _startBoxes;

  late Pos player;
  late List<Box> boxes;
  int moves = 0;
  int pushes = 0;
  final List<_Snapshot> _history = [];

  SokobanGame(this.level) {
    rows = level.rows.length;
    cols = level.rows.fold(0, (m, r) => r.length > m ? r.length : m);
    var id = 0;
    final initial = <Box>[];
    Pos? start;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < level.rows[r].length; c++) {
        final ch = level.rows[r][c];
        final p = (r, c);
        switch (ch) {
          case '#':
            walls.add(p);
          case '.':
            goalOrder[p] = 0;
            goalColor[p] = 0;
          case r'$':
            initial.add(Box(id++, p));
          case '*':
            goalOrder[p] = 0;
            goalColor[p] = 0;
            initial.add(Box(id++, p));
          case '@':
            start = p;
          case '+':
            goalOrder[p] = 0;
            goalColor[p] = 0;
            start = p;
          default:
            final n = int.tryParse(ch);
            final lower = 'abcd'.indexOf(ch);
            final upper = 'ABCD'.indexOf(ch);
            if (n != null) {
              goalOrder[p] = n;
              goalColor[p] = 0;
            } else if (lower >= 0) {
              goalOrder[p] = 0;
              goalColor[p] = lower + 1;
            } else if (upper >= 0) {
              initial.add(Box(id++, p, upper + 1));
            }
        }
      }
    }
    _startPlayer = start!;
    _startBoxes = List.unmodifiable(initial);
    _computeFloor();
    reset();
  }

  Iterable<Pos> get goals => goalOrder.keys;

  /// 플레이어에서 벽에 막히지 않고 닿을 수 있는 칸만 바닥으로 그린다.
  void _computeFloor() {
    final stack = <Pos>[_startPlayer];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (p.$1 < 0 || p.$2 < 0 || p.$1 >= rows || p.$2 >= cols) continue;
      if (walls.contains(p) || !floor.add(p)) continue;
      stack
        ..add((p.$1 + 1, p.$2))
        ..add((p.$1 - 1, p.$2))
        ..add((p.$1, p.$2 + 1))
        ..add((p.$1, p.$2 - 1));
    }
  }

  void reset() {
    player = _startPlayer;
    boxes = List.of(_startBoxes);
    moves = 0;
    pushes = 0;
    _history.clear();
  }

  bool get canUndo => _history.isNotEmpty;

  /// 지금 판으로 오기까지의 걸음 방향(되돌린 걸음은 빠진다). 저장·복원용.
  String get path => _history.map((h) => h.dir).join();

  /// [path]를 처음부터 다시 걸어 판을 복원한다. [totalMoves]는 되돌리기까지 센 걸음 수.
  /// 저장된 경로가 지금 규칙과 맞지 않으면 false를 돌려주고 처음 상태로 둔다.
  bool restore(String path, int totalMoves) {
    reset();
    const dirs = {'U': (-1, 0), 'D': (1, 0), 'L': (0, -1), 'R': (0, 1)};
    for (final ch in path.split('')) {
      final d = dirs[ch];
      final res = d == null ? MoveResult.blocked : move(d.$1, d.$2);
      if (res != MoveResult.moved && res != MoveResult.pushed) {
        reset();
        return false;
      }
    }
    moves = totalMoves < _history.length ? _history.length : totalMoves;
    return true;
  }

  int? get limit => level.limit;
  int? get movesLeft => limit == null ? null : limit! - moves;

  /// [color] 상자를 [goal]에 놓으면 "찬" 것으로 치는가.
  bool accepts(int color, Pos goal) {
    final gc = goalColor[goal] ?? 0;
    return gc == 0 || gc == color;
  }

  /// 목표 [goal]에 맞는 상자가 올라가 있는가.
  bool goalFilled(Pos goal) {
    final b = _boxAt(goal);
    return b != null && accepts(b.color, goal);
  }

  bool get solved => goals.every(goalFilled);

  int get filledGoals => goals.where(goalFilled).length;

  /// 순서 규칙상 지금 상자를 받을 수 있는 꽃인가 (순서 없는 꽃은 항상 열림).
  bool goalOpen(Pos goal, {Box? excluding}) {
    final n = goalOrder[goal] ?? 0;
    if (n <= 1) return true;
    for (final entry in goalOrder.entries) {
      if (entry.value > 0 && entry.value < n) {
        final b = _boxAt(entry.key);
        if (b == null || b == excluding) return false;
      }
    }
    return true;
  }

  /// 잠금 규칙: 받아주는 꽃 위의 상자는 움직일 수 없다.
  bool isLocked(Box b) =>
      level.lock && goalOrder.containsKey(b.pos) && accepts(b.color, b.pos);

  Box? _boxAt(Pos p) {
    for (final b in boxes) {
      if (b.pos == p) return b;
    }
    return null;
  }

  MoveResult move(int dr, int dc) {
    final next = (player.$1 + dr, player.$2 + dc);
    if (walls.contains(next)) return MoveResult.blocked;
    final box = _boxAt(next);
    var result = MoveResult.moved;
    final snap = _Snapshot(
      player,
      boxes,
      moves,
      pushes,
      dr < 0
          ? 'U'
          : dr > 0
          ? 'D'
          : dc < 0
          ? 'L'
          : 'R',
    );
    if (box != null) {
      if (isLocked(box)) return MoveResult.locked;
      final beyond = (next.$1 + dr, next.$2 + dc);
      if (walls.contains(beyond) || _boxAt(beyond) != null) {
        return MoveResult.blocked;
      }
      if (goalOrder.containsKey(beyond) && !goalOpen(beyond, excluding: box)) {
        return MoveResult.orderBlocked;
      }
      boxes = [
        for (final b in boxes) b.id == box.id ? Box(b.id, beyond, b.color) : b,
      ];
      pushes++;
      result = MoveResult.pushed;
    }
    _history.add(snap);
    player = next;
    moves++;
    return result;
  }

  /// 되돌리기. 걸음 제한 단계에서는 되돌리기도 1걸음으로 센다.
  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    player = s.player;
    boxes = s.boxes;
    moves = limit == null ? s.moves : moves + 1;
    pushes = s.pushes;
  }
}
