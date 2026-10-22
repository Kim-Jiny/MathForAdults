#!/usr/bin/env python3
"""소코반 100단계 생성기 — 무작위 방을 만들고 최단 풀이를 구해 난이도에 맞는 판만 고른다.

사용: python3 tool/gen_sokoban.py  → lib/screens/game/sokoban_levels.dart 갱신
규칙(게임과 동일):
  - 걸음 제한: 최단 걸음 × 배율 + 여유. 되돌리기도 1걸음.
  - 숫자 목표(1~9)는 순서가 있다. 1..n-1번이 모두 차야 n번 칸에 상자를 밀어 넣을 수 있다.
  - 색 맞추기: 대문자 A~D = 색 상자, 소문자 a~d = 같은 색 목표. 색이 맞아야 "찬" 것으로 친다.
  - 잠금: 제 자리(받아주는 목표)에 놓인 상자는 잠겨서 더는 밀 수 없다.
  - 폭탄: 제한 시간(초). 풀이 걸음 수에서 정해 둔다.
"""
import heapq
import math
import random
import sys
import time
from collections import deque
from multiprocessing import Pool

DIRS = [('U', -1, 0), ('D', 1, 0), ('L', 0, -1), ('R', 0, 1)]

HANDMADE = [
    ('첫걸음', ['#####', '#@$.#', '#####']),
    ('방향 바꾸기', ['#######', '#     #', '# .$@ #', '#     #', '#######']),
    ('두 개 옮기기', ['#######', '#.    #', '# $$ .#', '#  @  #', '#######']),
    ('작은 창고', ['  ####', '###  ####', '#     $ #', '# #  #$ #', '# . .#@ #', '#########']),
    ('줄 세우기', ['########', '#      #', '# .**$@#', '#      #', '#####  #', '    ####']),
    ('가운데 모으기', ['#########', '#   .   #', '#  $ $  #', '# . @ . #', '#  $    #', '#       #', '#########']),
    ('좁은 길', ['  #####', '###   #', '#  $# #', '# .@. #', '# $ $ #', '#  .  #', '#######']),
]


def parse(rows):
    """goals: 칸 -> (순서, 색), boxes: {(칸, 색)}."""
    walls, goals, boxes, player = set(), {}, set(), None
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            p = (r, c)
            if ch == '#':
                walls.add(p)
            elif ch == '.':
                goals[p] = (0, 0)
            elif ch.isdigit():
                goals[p] = (int(ch), 0)
            elif ch in 'abcd':
                goals[p] = (0, 'abcd'.index(ch) + 1)
            elif ch == '$':
                boxes.add((p, 0))
            elif ch in 'ABCD':
                boxes.add((p, 'ABCD'.index(ch) + 1))
            elif ch == '*':
                goals[p] = (0, 0)
                boxes.add((p, 0))
            elif ch == '@':
                player = p
            elif ch == '+':
                goals[p] = (0, 0)
                player = p
    return walls, goals, frozenset(boxes), player


def alive_cells(walls, goals, h, w):
    """상자를 밀어 목표까지 보낼 수 있는 칸 (역방향으로 당겨 보며 계산)."""
    alive = set(goals)
    q = deque(goals)
    while q:
        r, c = q.popleft()
        for _, dr, dc in DIRS:
            b = (r + dr, c + dc)       # 당기기 전 상자 위치
            p = (r + 2 * dr, c + 2 * dc)  # 당기는 사람 위치
            if b in alive or b in walls or p in walls:
                continue
            if not (0 <= b[0] < h and 0 <= b[1] < w):
                continue
            alive.add(b)
            q.append(b)
    return alive


def solve(walls, goals, boxes, player, cap, lock=False):
    """Dijkstra(걸음 수 기준). 반환: (최단 걸음, 풀이 문자열) 또는 None."""
    h = max(r for r, _ in walls) + 2
    w = max(c for _, c in walls) + 2
    alive = alive_cells(walls, goals, h, w)
    ordered = any(o > 0 for o, _ in goals.values())
    by_idx = {o: c for c, (o, _) in goals.items() if o > 0}

    def accepts(color, g):
        gc = goals[g][1]
        return gc == 0 or gc == color

    def complete(bx):
        at = dict(bx)
        return all(g in at and accepts(at[g], g) for g in goals)

    start = (player, boxes)
    dist = {start: 0}
    parent = {start: None}
    pq = [(0, 0, start)]
    tie = 0
    pops = 0
    while pq:
        d, _, st = heapq.heappop(pq)
        if dist[st] < d:
            continue
        pl, bx = st
        if complete(bx):
            out = []
            while parent[st] is not None:
                st, seg = parent[st]
                out.append(seg)
            return d, ''.join(reversed(out))
        pops += 1
        if pops > cap:
            return None
        occ = {p for p, _ in bx}
        reach = {pl: ''}
        q = deque([pl])
        while q:
            cur = q.popleft()
            for ch, dr, dc in DIRS:
                n = (cur[0] + dr, cur[1] + dc)
                if n in reach or n in walls or n in occ:
                    continue
                reach[n] = reach[cur] + ch
                q.append(n)
        for item in bx:
            box, color = item
            if lock and box in goals and accepts(color, box):
                continue  # 잠긴 상자
            rest = bx - {item}
            rest_pos = occ - {box}
            for ch, dr, dc in DIRS:
                stand = (box[0] - dr, box[1] - dc)
                if stand not in reach:
                    continue
                dest = (box[0] + dr, box[1] + dc)
                if dest in walls or dest in occ or dest not in alive:
                    continue
                if ordered:
                    n = goals.get(dest, (0, 0))[0]
                    if n > 0 and any(by_idx[i] not in rest_pos for i in range(1, n)):
                        continue
                nb = rest | {(dest, color)}
                key = (box, nb)
                nd = d + len(reach[stand]) + 1
                if nd < dist.get(key, 1 << 30):
                    dist[key] = nd
                    parent[key] = (st, reach[stand] + ch)
                    tie += 1
                    heapq.heappush(pq, (nd, tie, key))
    return None


def connected(walls, h, w):
    cells = [(r, c) for r in range(h) for c in range(w) if (r, c) not in walls]
    seen = {cells[0]}
    q = deque([cells[0]])
    while q:
        r, c = q.popleft()
        for _, dr, dc in DIRS:
            n = (r + dr, c + dc)
            if n not in seen and n not in walls and 0 <= n[0] < h and 0 <= n[1] < w:
                seen.add(n)
                q.append(n)
    return len(seen) == len(cells)


def random_level(rng, w, h, k, density, pulls, colored):
    """풀린 상태에서 상자를 무작위로 당겨(역방향 이동) 섞는다 — 풀 수 있는 판이 보장된다."""
    walls = {(r, c) for r in range(h) for c in range(w) if r in (0, h - 1) or c in (0, w - 1)}
    inner = [(r, c) for r in range(1, h - 1) for c in range(1, w - 1)]
    for p in rng.sample(inner, int(len(inner) * density)):
        walls.add(p)
        if not connected(walls, h, w):
            walls.discard(p)
    floor = [p for p in inner if p not in walls]
    if len(floor) < k * 3 + 3:
        return None
    gl = rng.sample(floor, k)
    colors = [(i % 4) + 1 if colored else 0 for i in range(k)]
    goals = {g: (0, colors[i]) for i, g in enumerate(gl)}
    boxes = {g: colors[i] for i, g in enumerate(gl)}  # 칸 -> 색
    player = rng.choice([p for p in floor if p not in boxes])
    done = 0
    for _ in range(pulls * 40):
        if done >= pulls:
            break
        _, dr, dc = rng.choice(DIRS)
        nxt = (player[0] + dr, player[1] + dc)
        if nxt in walls:
            continue
        behind = (player[0] - dr, player[1] - dc)
        if behind in boxes and nxt not in boxes and rng.random() < 0.85:
            boxes[player] = boxes.pop(behind)
            player = nxt
            done += 1
        elif nxt not in boxes:
            player = nxt
    # 목표 위에 상자·플레이어가 서 있으면 글자 하나로 색/순서를 표현할 수 없으니 버린다.
    if any(b in goals for b in boxes) or player in goals:
        return None
    return walls, goals, frozenset(boxes.items()), player


def render(walls, goals, boxes, player):
    h = max(r for r, _ in walls) + 1
    w = max(c for _, c in walls) + 1
    at = dict(boxes)
    rows = []
    for r in range(h):
        line = ''
        for c in range(w):
            p = (r, c)
            if p in walls:
                line += '#'
            elif p == player:
                line += '+' if p in goals else '@'
            elif p in at:
                line += '*' if p in goals else ('$' if at[p] == 0 else 'ABCD'[at[p] - 1])
            elif p in goals:
                o, col = goals[p]
                line += str(o) if o else ('abcd'[col - 1] if col else '.')
            else:
                line += ' '
        rows.append(line.rstrip())
    return rows


CHAPTERS = [(7, '새싹 마당'), (13, '걸음 제한'), (25, '순서의 꽃'), (40, '색깔 선물'),
            (55, '잠금 선물'), (70, '폭탄 선물'), (100, '대모험')]


def chapter(n):
    return next(name for last, name in CHAPTERS if n <= last)


def mech(n):
    m = set()
    if n < 8:
        return m
    m.add('steps')
    if n < 14:
        pass
    elif n <= 25:
        if n % 3 == 2:
            m.add('order')
    elif n <= 40:
        if n % 2 == 0:
            m.add('color')
        elif n % 5 == 0:
            m.add('order')
    elif n <= 55:
        if n % 2 == 1:
            m.add('lock')
        if n % 3 == 0:
            m.add('color')
        elif n % 4 == 0:
            m.add('order')
    elif n <= 70:
        if n % 2 == 0:
            m.add('bomb')
        if n % 3 == 0:
            m.add('lock')
        if n % 3 == 1:
            m.add('color')
        elif n % 5 == 0:
            m.add('order')
    else:
        m |= {0: {'color', 'lock'}, 1: {'order', 'bomb'},
              2: {'color', 'lock', 'bomb'}, 3: {'order', 'lock', 'bomb'}}[n % 4]
    return m


def params(n):
    """n = 단계 번호(1부터). 단계가 오를수록 상자·방·최단 걸음이 늘어난다."""
    t = (n - 8) / 92
    k = 1 if n <= 10 else 2 if n <= 25 else 3 if n <= 45 else 4 if n <= 80 else 5
    target = 12 + (85 - 12) * (t ** 0.85)
    if k == 1:
        target = min(target, 24)
    size = 5 + round(t * 4)
    return k, target, size


def limit_for(n, par):
    if n <= 7:
        return None
    mult, extra = (
        (1.8, 8) if n <= 20 else (1.6, 6) if n <= 35 else (1.45, 5) if n <= 50
        else (1.35, 4) if n <= 75 else (1.25, 3)
    )
    return math.ceil(par * mult) + extra


def seconds_for(n, par):
    return math.ceil(par * (0.8 if n <= 85 else 0.7) + 15)


def make_slot(args):
    n, seed = args
    rng = random.Random(seed)
    k, target, size = params(n)
    m = mech(n)
    ordered, colored, lock = 'order' in m, 'color' in m, 'lock' in m
    hard = n >= 36
    cap = 60000 + n * 800 if hard else 40000 + n * 2500
    deadline = time.time() + (170 if hard else 80)
    best = None
    tries = 0
    while time.time() < deadline:
        tries += 1
        w = max(5, min(9, size + rng.randint(-1, 1) + (1 if k >= 3 else 0)))
        h = max(5, min(9, size + rng.randint(-1, 1)))
        pulls = int(target * (rng.uniform(0.6, 1.3) if hard else rng.uniform(0.25, 0.7))) + k
        cand = random_level(rng, w, h, k, rng.uniform(0.04, 0.2), pulls, colored)
        if not cand:
            continue
        walls, goals, boxes, player = cand
        res = solve(walls, goals, boxes, player, cap, lock)
        if not res:
            continue
        par, sol = res
        if ordered:
            gl = list(goals)
            bestord = None
            for _ in range(6):
                perm = list(range(1, k + 1))
                rng.shuffle(perm)
                g2 = {g: (o, 0) for g, o in zip(gl, perm)}
                r2 = solve(walls, g2, boxes, player, cap, lock)
                if r2 and r2[0] >= par + 4 and (not bestord or r2[0] > bestord[0][0]):
                    bestord = (r2, g2)
            if not bestord:
                continue
            (par, sol), goals = bestord
        score = -par if hard else abs(par - target)
        if not best or score < best[0]:
            best = (score, par, sol, render(walls, goals, boxes, player))
        if hard:
            if par >= target:
                break
        elif best[0] <= target * 0.12 and tries >= 6:
            break
    return n, best


def load_existing(path):
    """이미 생성된 파일에서 (이름, 판, 최단, 풀이)를 읽어 일부 단계만 다시 만들 수 있게 한다."""
    import re
    src = open(path).read()
    out = {}
    for i, blk in enumerate(src.split('  SokobanLevel(')[1:], start=1):
        name = re.search(r"'([^']*)',", blk).group(1)
        rows = re.findall(r"r'([^']*)',", blk)
        par = int(re.search(r'par: (\d+)', blk).group(1))
        sol = re.search(r"solution: '([UDLR]*)'", blk).group(1)
        m = re.search(r' (\d+)$', name)
        out[int(m.group(1)) if m else i] = (name, rows, par, sol)
    return out


def main():
    t0 = time.time()
    results = {}
    first = int(sys.argv[1]) if len(sys.argv) > 1 else 8  # 이 단계부터 다시 만든다
    last = int(sys.argv[2]) if len(sys.argv) > 2 else 100  # 이 단계까지
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 2000
    if first > 8 or last < 100:
        results = {n: v for n, v in load_existing('lib/screens/game/sokoban_levels.dart').items() if not first <= n <= last}
    else:
        # 손으로 만든 1~7단계
        for i, (name, rows) in enumerate(HANDMADE, start=1):
            walls, goals, boxes, player = parse(rows)
            par, sol = solve(walls, goals, boxes, player, 2_000_000)
            results[i] = (name, rows, par, sol)
    jobs = [(n, seed + n) for n in range(first, last + 1)]
    with Pool(8) as pool:
        for n, best in pool.imap_unordered(make_slot, jobs):
            if not best:
                print('FAILED', n, file=sys.stderr, flush=True)
                continue
            _, par, sol, rows = best
            results[n] = (None, rows, par, sol)
            print(n, sorted(mech(n)), 'par', par, 'target', round(params(n)[1]), f'{time.time() - t0:.0f}s', flush=True)
    out = ["// 자동 생성 파일 — tool/gen_sokoban.py 로 만든다. 직접 고치지 말 것.", "import 'sokoban_logic.dart';", '',
           '// # 벽  . 목표  1~9 순서 목표  a~d 색 목표  $ 상자  A~D 색 상자  * 목표 위 상자  @ 플레이어  + 목표 위 플레이어',
           'const sokobanLevels = <SokobanLevel>[']
    for n in sorted(results):
        name, rows, par, sol = results[n]
        if name is None:
            name = f'{chapter(n)} {n}'
        m = mech(n)
        out.append('  SokobanLevel(')
        out.append(f"    '{name}',")
        out.append('    [')
        for r in rows:
            out.append(f"      r'{r}',")
        out.append('    ],')
        out.append(f'    par: {par},')
        if 'steps' in m:
            out.append(f'    limit: {limit_for(n, par)},')
        if 'bomb' in m:
            out.append(f'    seconds: {seconds_for(n, par)},')
        if 'lock' in m:
            out.append('    lock: true,')
        out.append(f"    solution: '{sol}',")
        out.append('  ),')
    out.append('];')
    open('lib/screens/game/sokoban_levels.dart', 'w').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
