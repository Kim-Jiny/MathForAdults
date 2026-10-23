import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ads/ad_service.dart';
import '../../services/usage_events.dart';
import '../../state/app_state.dart';
import '../../state/iap_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ads/banner_ad_slot.dart';
import '../../widgets/app_card.dart';
import '../../widgets/mascot.dart';
import 'sokoban_levels.dart';
import 'sokoban_logic.dart';
import 'sokoban_store.dart';

const _kBestKey = 'sokoban_best_v1'; // "레벨:최소이동" 목록
const _kTipsKey = 'sokoban_tips_v1'; // 설명을 본 규칙 이름

/// 단계 묶음: (마지막 단계 번호, 이름, 이모지)
const _chapters = <(int, String, String)>[
  (7, '새싹 마당', '🌱'),
  (13, '걸음 제한', '👣'),
  (25, '순서의 꽃', '🔢'),
  (40, '색깔 선물', '🎨'),
  (55, '잠금 선물', '🔒'),
  (70, '폭탄 선물', '💣'),
  (100, '대모험', '🚀'),
];

/// 색 상자/꽃 팔레트 (0 = 보통 노랑).
const _palette = <Color>[
  AppColors.sunny,
  Color(0xFFFF7B8B),
  Color(0xFF5DB5F0),
  Color(0xFFB07CF0),
  Color(0xFF7ED957),
];

const _ruleInfo = <SokobanRule, (String, String)>{
  SokobanRule.steps: ('👣 걸음 제한!', '정해진 걸음 안에 끝내야 해요.\n되돌리기도 1걸음으로 세요.'),
  SokobanRule.order: ('🔢 순서대로!', '번호 꽃부터 차례로 채워요.\n앞 번호가 비어 있으면 다음 꽃엔 못 놓아요.'),
  SokobanRule.color: ('🎨 색 맞추기!', '색깔 선물은 같은 색 꽃자리에 놓아야\n채운 걸로 쳐요.'),
  SokobanRule.lock: ('🔒 잠금 상자!', '자리에 놓은 상자는 잠겨서\n다시는 밀 수 없어요. 신중하게!'),
  SokobanRule.bomb: ('💣 폭탄 타이머!', '첫 걸음부터 시간이 줄어요.\n0이 되면 펑! 빠르게 움직여요.'),
};

const _ruleEmoji = <SokobanRule, String>{
  SokobanRule.steps: '👣',
  SokobanRule.order: '🔢',
  SokobanRule.color: '🎨',
  SokobanRule.lock: '🔒',
  SokobanRule.bomb: '💣',
};

Map<int, int> _readBest(WidgetRef ref) {
  final raw = ref.read(sharedPreferencesProvider).getStringList(_kBestKey);
  final out = <int, int>{};
  for (final e in raw ?? const <String>[]) {
    final p = e.split(':');
    if (p.length == 2) out[int.parse(p[0])] = int.parse(p[1]);
  }
  return out;
}

Future<void> _saveBest(WidgetRef ref, int level, int moves) async {
  final best = _readBest(ref);
  if ((best[level] ?? 1 << 30) <= moves) return;
  best[level] = moves;
  await ref.read(sharedPreferencesProvider).setStringList(_kBestKey, [
    for (final e in best.entries) '${e.key}:${e.value}',
  ]);
}

/// 이 단계에서 처음 등장하는 규칙.
Set<SokobanRule> _newRules(int level) {
  final seen = <SokobanRule>{};
  for (var i = 0; i < level; i++) {
    seen.addAll(sokobanLevels[i].rules);
  }
  return sokobanLevels[level].rules.difference(seen);
}

// ───────────────────────── 레벨 선택 ─────────────────────────

/// 새싹이의 선물 창고 — 레벨 선택 화면.
class SokobanMenuScreen extends ConsumerStatefulWidget {
  const SokobanMenuScreen({super.key});

  @override
  ConsumerState<SokobanMenuScreen> createState() => _SokobanMenuState();
}

class _SokobanMenuState extends ConsumerState<SokobanMenuScreen> {
  Future<void> _open(int i) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SokobanPlayScreen(level: i)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = _readBest(ref);
    final store = SokobanStore(ref.read(sharedPreferencesProvider));
    final saved = store.savedLevels;
    // 앞에서부터 이어서 깬 단계 바로 다음 한 단계까지만 열린다.
    var prefix = 0;
    while (best.containsKey(prefix) && prefix < sokobanLevels.length) {
      prefix++;
    }
    final unlocked = prefix + 1;
    var stars = 0;
    for (final e in best.entries) {
      stars += sokobanLevels[e.key].starsFor(e.value);
    }

    final children = <Widget>[
      Row(
        children: [
          const Mascot(size: 84, bounce: true),
          const SizedBox(width: 12),
          Expanded(
            child: _Bubble(
              '선물상자를 밀어서 🌸 꽃자리에 올려주세요!\n'
              '⭐ 모은 별 $stars / ${sokobanLevels.length * 3}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      const BannerAdSlot(
        placement: BannerPlacement.sokoban,
        margin: EdgeInsets.only(top: 14),
      ),
    ];
    var start = 0;
    for (final (last, name, emoji) in _chapters) {
      final from = start; // LayoutBuilder가 나중에 실행되므로 현재 값을 붙잡아 둔다
      final end = math.min(last, sokobanLevels.length);
      children
        ..add(const SizedBox(height: 22))
        ..add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              '$emoji $name  ·  ${from + 1}~$end단계',
              style: theme.textTheme.titleMedium,
            ),
          ),
        )
        ..add(
          LayoutBuilder(
            builder: (_, c) {
              final w = (c.maxWidth - 10 * 4) / 5;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = from; i < end; i++)
                    SizedBox(
                      width: w,
                      height: w * 1.08,
                      child: _LevelTile(
                        number: i + 1,
                        stars: best[i] == null
                            ? 0
                            : sokobanLevels[i].starsFor(best[i]!),
                        locked: i >= unlocked && !saved.contains(i),
                        resume: saved.contains(i),
                        onTap: () => _open(i),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      start = end;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('🎁 새싹이의 선물 창고')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: children,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _Bubble(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 2),
      ),
      child: Text(text, style: style),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int number;
  final int stars;
  final bool locked;
  final bool resume; // 진행 중인 판이 저장돼 있다
  final VoidCallback onTap;
  const _LevelTile({
    required this.number,
    required this.stars,
    required this.locked,
    this.resume = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = stars > 0;
    final base = done ? AppColors.correct : AppColors.primary;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: scheme.outlineVariant, offset: const Offset(0, 3)),
          ],
        ),
        child: Material(
          color: base.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: base.withValues(alpha: 0.45), width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: locked ? null : onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                locked
                    ? const Text('🔒', style: TextStyle(fontSize: 18))
                    : Text('$number', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  locked
                      ? ''
                      : resume
                      ? '▶ 이어서'
                      : '⭐' * stars + '·' * (3 - stars),
                  style: const TextStyle(fontSize: 9, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 플레이 화면 ─────────────────────────

enum _Phase { playing, won, outOfSteps, exploded }

class SokobanPlayScreen extends ConsumerStatefulWidget {
  final int level;
  const SokobanPlayScreen({super.key, required this.level});

  @override
  ConsumerState<SokobanPlayScreen> createState() => _SokobanPlayState();
}

class _SokobanPlayState extends ConsumerState<SokobanPlayScreen>
    with TickerProviderStateMixin {
  late final SokobanStore _store = SokobanStore(
    ref.read(sharedPreferencesProvider),
  );
  bool _busy = false; // 새로고침 확인·광고 중
  late int _level = widget.level;
  late SokobanGame _game = SokobanGame(sokobanLevels[_level]);
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  MascotMood _mood = MascotMood.happy;
  _Phase _phase = _Phase.playing;
  Offset _drag = Offset.zero;
  final _focus = FocusNode();

  // 폭탄 타이머
  final _timeLeft = ValueNotifier<double>(0);
  Timer? _ticker;
  final _clock = Stopwatch();
  double _elapsedBase = 0; // 이어하기로 복원한 시점까지 이미 쓴 시간(초)

  // 막혔을 때 잠깐 뜨는 안내
  String? _hint;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
    _enter();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTips());
  }

  /// 단계에 들어올 때 한 번: 저장된 판이 있으면 이어서(sk_resume), 아니면 새로(sk_start).
  void _enter() {
    UsageEvents.instance.log(
      _resume() ? 'sk_resume' : 'sk_start',
      level: _level + 1,
    );
  }

  /// 저장된 진행 상황이 있으면 그 자리에서 이어서 한다. 이어했으면 true.
  bool _resume() {
    final s = _store.load(_level);
    if (s == null) return false;
    if (!_game.restore(s.path, s.moves)) {
      _store.clear(_level);
      return false;
    }
    final total = _lv.seconds;
    if (total != null && s.timeLeft != null) {
      _elapsedBase = total - s.timeLeft!.clamp(0, total.toDouble());
      _timeLeft.value = s.timeLeft!;
    }
    return true;
  }

  void _logFail(String why) =>
      UsageEvents.instance.log('sk_fail', level: _level + 1, extra: why);

  /// 진행 중이면 저장하고, 끝났거나 처음 상태면 저장을 지운다.
  void _persist() {
    if (_phase != _Phase.playing || _game.path.isEmpty) {
      _store.clear(_level);
      return;
    }
    _store.save(
      _level,
      SokobanSave(
        _game.path,
        _game.moves,
        _lv.seconds == null ? null : _timeLeft.value,
      ),
    );
  }

  @override
  void dispose() {
    if (_phase == _Phase.playing && _game.path.isNotEmpty) _persist();
    _ticker?.cancel();
    _hintTimer?.cancel();
    _timeLeft.dispose();
    _hop.dispose();
    _pulse.dispose();
    _confetti.dispose();
    _focus.dispose();
    super.dispose();
  }

  SokobanLevel get _lv => sokobanLevels[_level];

  void _resetTimer() {
    _ticker?.cancel();
    _clock
      ..stop()
      ..reset();
    _elapsedBase = 0;
    _timeLeft.value = (_lv.seconds ?? 0).toDouble();
  }

  void _startTimer() {
    final total = _lv.seconds;
    if (total == null || _clock.isRunning) return;
    _clock.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final left = total - _elapsedBase - _clock.elapsedMilliseconds / 1000;
      _timeLeft.value = math.max(0, left);
      if (left <= 0 && _phase == _Phase.playing) {
        _ticker?.cancel();
        _clock.stop();
        HapticFeedback.heavyImpact();
        _store.clear(_level);
        _logFail('bomb');
        setState(() {
          _phase = _Phase.exploded;
          _mood = MascotMood.sleepy;
        });
      }
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _clock.stop();
  }

  /// 처음 만나는 규칙은 설명 카드를 한 번 보여준다.
  Future<void> _showTips() async {
    if (!mounted) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final seen = prefs.getStringList(_kTipsKey)?.toSet() ?? <String>{};
    final fresh = _newRules(_level).where((r) => !seen.contains(r.name));
    if (fresh.isEmpty) return;
    await prefs.setStringList(
      _kTipsKey,
      {...seen, ...fresh.map((r) => r.name)}.toList(),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✨ 새로운 규칙!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in fresh) ...[
              Text(
                _ruleInfo[r]!.$1,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(_ruleInfo[r]!.$2),
              const SizedBox(height: 12),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('알겠어요!'),
          ),
        ],
      ),
    );
  }

  void _showHint(String text) {
    _hintTimer?.cancel();
    setState(() => _hint = text);
    _hintTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  /// 광고 제거를 구매했으면 전면 광고를 띄우지 않는다. 노출 정책은 AdService가 정한다.
  void _maybeShowInterstitial() {
    if (ref.read(adsRemovedProvider)) return;
    AdService.instance.maybeShowInterstitial(
      isMockExam: false,
      placement: 'next',
    );
  }

  void _move(int dr, int dc) {
    if (_phase != _Phase.playing) return;
    final res = _game.move(dr, dc);
    switch (res) {
      case MoveResult.blocked:
        HapticFeedback.selectionClick();
        setState(() => _mood = MascotMood.think);
        return;
      case MoveResult.orderBlocked:
        HapticFeedback.selectionClick();
        setState(() => _mood = MascotMood.think);
        _showHint('🔢 앞 번호 꽃부터 채워야 해요!');
        return;
      case MoveResult.locked:
        HapticFeedback.selectionClick();
        setState(() => _mood = MascotMood.think);
        _showHint('🔒 잠긴 상자는 밀 수 없어요!');
        return;
      case MoveResult.moved:
      case MoveResult.pushed:
        break;
    }
    HapticFeedback.lightImpact();
    _hop.forward(from: 0);
    _startTimer();
    setState(() {
      _mood = res == MoveResult.pushed ? MascotMood.cheer : MascotMood.happy;
      if (_game.solved) {
        _phase = _Phase.won;
        _mood = MascotMood.cheer;
        _stopTimer();
        _confetti.forward(from: 0);
        _saveBest(ref, _level, _game.moves);
        UsageEvents.instance.log(
          'sk_clear',
          level: _level + 1,
          value: _game.moves,
          extra: '${_lv.starsFor(_game.moves)}',
        );
      } else if ((_game.movesLeft ?? 1) <= 0) {
        _phase = _Phase.outOfSteps;
        _mood = MascotMood.sleepy;
        _stopTimer();
        _logFail('steps');
      }
    });
    _persist();
  }

  void _undo() {
    setState(() {
      _game.undo();
      _mood = MascotMood.happy;
      if ((_game.movesLeft ?? 1) <= 0) {
        _phase = _Phase.outOfSteps;
        _mood = MascotMood.sleepy;
        _stopTimer();
        _logFail('steps');
      }
    });
    _persist();
  }

  /// 진행 중인 판을 처음부터 다시 할 때: 확인 후 전면 광고를 보여주고 다시 시작한다.
  /// 아직 한 걸음도 안 움직였으면 광고 없이 바로 다시 시작한다.
  Future<void> _onRefresh() async {
    if (_busy) return;
    if (_phase != _Phase.playing || _game.moves == 0) {
      _restart(count: false); // 아직 안 움직였으면 새 시도로 세지 않는다
      return;
    }
    setState(() => _busy = true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔄 처음부터 다시 할까요?'),
        content: const Text('지금까지 진행한 내용이 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다시 하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    UsageEvents.instance.log(
      'sk_restart',
      level: _level + 1,
      value: _game.moves,
    );
    // 광고 제거 구매자는 광고 없이 바로 시작한다.
    if (!ref.read(adsRemovedProvider)) {
      await AdService.instance.showInterstitialNow();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _restart();
  }

  void _restart({int? level, bool count = true}) {
    _store.clear(_level); // 지금 단계의 저장은 버린다
    setState(() {
      if (level != null) {
        _level = level;
        _game = SokobanGame(sokobanLevels[level]);
      } else {
        _game.reset();
      }
      _phase = _Phase.playing;
      _mood = MascotMood.happy;
      _hint = null;
      _confetti.reset();
      _resetTimer();
    });
    if (level != null) {
      _enter(); // 다음 단계에 진행 중이던 판이 있으면 이어서
    } else if (count) {
      UsageEvents.instance.log('sk_start', level: _level + 1); // 같은 단계 새 시도
    }
    if (level != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTips());
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _move(1, 0);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _move(0, -1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _move(0, 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _drag += d.delta;
    if (_drag.distance < 22) return;
    if (_drag.dx.abs() > _drag.dy.abs()) {
      _move(0, _drag.dx > 0 ? 1 : -1);
    } else {
      _move(_drag.dy > 0 ? 1 : -1, 0);
    }
    _drag = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = _game;
    final lv = _lv;
    final hasNext = _level + 1 < sokobanLevels.length;
    final playing = _phase == _Phase.playing;
    final left = g.movesLeft;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_level + 1}단계'),
          actions: [
            IconButton(
              tooltip: '되돌리기',
              onPressed: g.canUndo && playing ? _undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: '다시 시작',
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      left == null
                          ? '👣 ${g.moves}걸음'
                          : '👣 ${g.moves}/${lv.limit}',
                      warn: left != null && left <= 5,
                    ),
                    _Chip('🎁 ${g.filledGoals}/${g.goals.length}'),
                    if (lv.seconds != null)
                      ValueListenableBuilder<double>(
                        valueListenable: _timeLeft,
                        builder: (_, t, _) => _Chip(
                          '💣 ${t.ceil()}초',
                          warn: t <= 5 && _clock.isRunning,
                          pulse: _pulse,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _hint ??
                        [for (final r in lv.rules) _ruleEmoji[r]!].join('  '),
                    key: ValueKey(_hint),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _hint == null
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.wrong,
                      fontWeight: _hint == null ? null : FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (_) => _drag = Offset.zero,
                      onPanUpdate: _onPanUpdate,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final cell = math.min(
                                56.0,
                                math.min(
                                  c.maxWidth / g.cols,
                                  c.maxHeight / g.rows,
                                ),
                              );
                              return _Board(
                                game: g,
                                cell: cell,
                                mood: _mood,
                                hop: _hop,
                                pulse: _pulse,
                                won: _phase == _Phase.won,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (_phase == _Phase.won)
                      IgnorePointer(child: _Confetti(controller: _confetti)),
                  ],
                ),
              ),
              switch (_phase) {
                _Phase.playing => _DPad(onMove: _move),
                _Phase.won => _ResultPanel(
                  title: '🎉 클리어! ${g.moves}걸음',
                  stars: lv.starsFor(g.moves),
                  onRetry: _restart,
                  onNext: hasNext
                      ? () {
                          _maybeShowInterstitial();
                          _restart(level: _level + 1);
                        }
                      : null,
                  onMenu: () => Navigator.pop(context),
                ),
                _Phase.outOfSteps => _ResultPanel(
                  title: '👣 걸음을 다 썼어요',
                  subtitle: '조금만 더 효율적으로 밀어봐요!',
                  onRetry: _restart,
                  onMenu: () => Navigator.pop(context),
                ),
                _Phase.exploded => _ResultPanel(
                  title: '💥 펑! 시간이 다 됐어요',
                  subtitle: '이번엔 더 빠르게 움직여봐요!',
                  onRetry: _restart,
                  onMenu: () => Navigator.pop(context),
                ),
              },
              const SizedBox(height: 12),
              if (playing)
                Text(
                  '화면을 밀거나 버튼을 눌러 움직여요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const BannerAdSlot(
                placement: BannerPlacement.sokoban,
                margin: EdgeInsets.only(top: 8),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool warn;
  final Animation<double>? pulse;
  const _Chip(this.text, {this.warn = false, this.pulse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warn ? AppColors.wrong : AppColors.primary;
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: warn ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: warn ? AppColors.wrong : null,
        ),
      ),
    );
    final p = pulse;
    if (warn && p != null) {
      chip = AnimatedBuilder(
        animation: p,
        builder: (_, child) =>
            Transform.scale(scale: 1 + 0.08 * p.value, child: child),
        child: chip,
      );
    }
    return chip;
  }
}

// ───────────────────────── 보드 ─────────────────────────

class _Board extends StatelessWidget {
  final SokobanGame game;
  final double cell;
  final MascotMood mood;
  final AnimationController hop;
  final AnimationController pulse;
  final bool won;

  const _Board({
    required this.game,
    required this.cell,
    required this.mood,
    required this.hop,
    required this.pulse,
    required this.won,
  });

  Offset _at(Pos p) => Offset(p.$2 * cell, p.$1 * cell);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final g = game;
    const dur = Duration(milliseconds: 90);
    Widget tile(Pos p, Widget child) => Positioned(
      left: _at(p).dx,
      top: _at(p).dy,
      width: cell,
      height: cell,
      child: child,
    );

    return SizedBox(
      width: g.cols * cell,
      height: g.rows * cell,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in g.floor)
            tile(
              p,
              Container(
                margin: const EdgeInsets.all(0.5),
                decoration: BoxDecoration(
                  color: (p.$1 + p.$2).isEven
                      ? (dark
                            ? const Color(0xFF2B2640)
                            : const Color(0xFFFFF1D9))
                      : (dark
                            ? const Color(0xFF332D4C)
                            : const Color(0xFFFFE9C6)),
                  borderRadius: BorderRadius.circular(cell * 0.14),
                ),
              ),
            ),
          for (final p in g.walls)
            // 바닥과 이어진 벽만 그려서 바깥 여백은 비운다.
            if (_touchesFloor(p))
              tile(
                p,
                Padding(
                  padding: EdgeInsets.all(cell * 0.03),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF5B4FB5) : AppColors.primary,
                      borderRadius: BorderRadius.circular(cell * 0.24),
                      boxShadow: [
                        BoxShadow(
                          color: dark
                              ? const Color(0xFF3E3580)
                              : const Color(0xFF5B4DD0),
                          offset: Offset(0, cell * 0.08),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: const Alignment(-0.5, -0.5),
                      child: Container(
                        width: cell * 0.2,
                        height: cell * 0.1,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(cell),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          for (final p in g.goals)
            tile(
              p,
              AnimatedBuilder(
                animation: pulse,
                builder: (_, _) => CustomPaint(
                  painter: _FlowerPainter(
                    pulse.value,
                    color: g.goalColor[p] ?? 0,
                    order: g.goalOrder[p] ?? 0,
                    open: g.goalOpen(p),
                  ),
                ),
              ),
            ),
          for (final b in g.boxes)
            AnimatedPositioned(
              key: ValueKey('box${b.id}'),
              duration: dur,
              curve: Curves.easeOut,
              left: _at(b.pos).dx,
              top: _at(b.pos).dy,
              width: cell,
              height: cell,
              child: _BoxView(
                cell: cell,
                color: b.color,
                onGoal: g.goalFilled(b.pos) && g.goals.contains(b.pos),
                locked: g.isLocked(b),
              ),
            ),
          AnimatedPositioned(
            duration: dur,
            curve: Curves.easeOut,
            left: _at(g.player).dx,
            top: _at(g.player).dy,
            width: cell,
            height: cell,
            child: AnimatedBuilder(
              animation: hop,
              builder: (_, child) {
                final t = hop.value;
                final lift = math.sin(t * math.pi) * cell * 0.22;
                // 폴짝 뛸 때 위아래로 말랑하게 늘었다 줄어든다.
                final stretch = math.sin(t * math.pi) * 0.08;
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: Transform.scale(
                    scaleX: 1 - stretch,
                    scaleY: 1 + stretch,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(cell * 0.04),
                child: Mascot(size: cell * 0.92, mood: mood, bounce: won),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _touchesFloor(Pos p) {
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (game.floor.contains((p.$1 + dr, p.$2 + dc))) return true;
      }
    }
    return false;
  }
}

/// 선물상자 — 보통은 노랑(자리에 놓으면 민트), 색 상자는 자기 색을 유지한다.
class _BoxView extends StatelessWidget {
  final double cell;
  final int color;
  final bool onGoal;
  final bool locked;
  const _BoxView({
    required this.cell,
    required this.color,
    required this.onGoal,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final plainDone = color == 0 && onGoal;
    final body = plainDone ? AppColors.accent : _palette[color];
    return AnimatedScale(
      scale: onGoal ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      child: Stack(
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: body),
              duration: const Duration(milliseconds: 250),
              builder: (_, c, _) =>
                  CustomPaint(painter: _GiftPainter(c ?? body, onGoal)),
            ),
          ),
          if (locked)
            Positioned(
              right: cell * 0.02,
              bottom: cell * 0.04,
              child: Text(
                '🔒',
                style: TextStyle(fontSize: cell * 0.3, height: 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _GiftPainter extends CustomPainter {
  final Color color;
  final bool done;
  _GiftPainter(this.color, this.done);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;
    final body = Rect.fromLTWH(u * 0.1, u * 0.18, u * 0.8, u * 0.72);
    final r = RRect.fromRectAndRadius(body, Radius.circular(u * 0.18));
    final dark = Color.lerp(color, AppColors.ink, 0.28)!;
    canvas.drawRRect(r.shift(Offset(0, u * 0.06)), Paint()..color = dark);
    canvas.drawRRect(r, Paint()..color = color);
    // 윗면 하이라이트
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(u * 0.16, u * 0.23, u * 0.68, u * 0.1),
        Radius.circular(u * 0.05),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // 리본 (색이 분홍 계열일 때도 잘 보이게 흰색/연분홍)
    final ribbonColor = done ? Colors.white : const Color(0xFFFFF2F6);
    final ribbon = Paint()..color = ribbonColor;
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      Rect.fromLTWH(u * 0.43, u * 0.18, u * 0.14, u * 0.72),
      ribbon,
    );
    canvas.drawRect(Rect.fromLTWH(u * 0.1, u * 0.5, u * 0.8, u * 0.14), ribbon);
    canvas.restore();
    for (final dx in [0.37, 0.63]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(u * dx, u * 0.16),
          width: u * 0.22,
          height: u * 0.16,
        ),
        ribbon,
      );
    }
    canvas.drawCircle(
      Offset(u * 0.5, u * 0.18),
      u * 0.07,
      Paint()..color = Color.lerp(ribbonColor, AppColors.ink, 0.15)!,
    );
    if (done) {
      final sp = Paint()..color = Colors.white;
      for (final o in [Offset(u * 0.2, u * 0.74), Offset(u * 0.8, u * 0.76)]) {
        canvas.drawCircle(o, u * 0.04, sp);
      }
    }
  }

  @override
  bool shouldRepaint(_GiftPainter o) => o.color != color || o.done != done;
}

/// 목표 자리: 살랑살랑 숨 쉬는 꽃. 순서 꽃은 가운데 번호, 닫힌 꽃은 흐리게.
class _FlowerPainter extends CustomPainter {
  final double t; // 0~1 (왕복)
  final int color;
  final int order;
  final bool open;
  _FlowerPainter(
    this.t, {
    required this.color,
    required this.order,
    required this.open,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = size.width;
    final scale = (open ? 0.88 + 0.12 * t : 0.72);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(open ? (t - 0.5) * 0.35 : 0);
    canvas.scale(scale);
    final base = color == 0 ? AppColors.pink : _palette[color];
    final petal = Paint()
      ..color = open
          ? base.withValues(alpha: 0.8)
          : const Color(0xFFB9B3C9).withValues(alpha: 0.6);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * u * 0.17,
        u * 0.13,
        petal,
      );
    }
    final centerR = order > 0 ? u * 0.15 : u * 0.11;
    canvas.drawCircle(
      Offset.zero,
      centerR,
      Paint()..color = open ? AppColors.sunny : const Color(0xFFE3DFEC),
    );
    if (order > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$order',
          style: TextStyle(
            fontSize: u * 0.24,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    } else {
      canvas.drawCircle(
        Offset(-u * 0.03, -u * 0.03),
        u * 0.035,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlowerPainter o) =>
      o.t != t || o.color != color || o.order != order || o.open != open;
}

// ───────────────────────── 컨트롤 / 연출 ─────────────────────────

class _DPad extends StatelessWidget {
  final void Function(int dr, int dc) onMove;
  const _DPad({required this.onMove});

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon, int dr, int dc) =>
        _PadKey(icon: icon, onTap: () => onMove(dr, dc));
    const gap = SizedBox(width: 64, height: 64);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [gap, key(Icons.keyboard_arrow_up_rounded, -1, 0), gap],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(Icons.keyboard_arrow_left_rounded, 0, -1),
            gap,
            key(Icons.keyboard_arrow_right_rounded, 0, 1),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [gap, key(Icons.keyboard_arrow_down_rounded, 1, 0), gap],
        ),
      ],
    );
  }
}

class _PadKey extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PadKey({required this.icon, required this.onTap});

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _down = false;
  Timer? _repeat;

  void _press() {
    setState(() => _down = true);
    widget.onTap(); // 손가락이 닿는 즉시 움직인다
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 260), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 110),
        (_) => widget.onTap(),
      );
    });
  }

  void _release() {
    _repeat?.cancel();
    if (_down) setState(() => _down = false);
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapCancel: _release,
      onTapUp: (_) => _release(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 56,
        height: 56,
        margin: EdgeInsets.fromLTRB(4, _down ? 8 : 4, 4, _down ? 0 : 4),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant, width: 2),
          boxShadow: _down
              ? null
              : [
                  BoxShadow(
                    color: scheme.outlineVariant,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(widget.icon, size: 34, color: AppColors.primary),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? stars;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final VoidCallback onMenu;
  const _ResultPanel({
    required this.title,
    this.subtitle,
    this.stars,
    required this.onRetry,
    this.onNext,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (stars != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: i < stars! ? 1 : 0.5),
                        duration: Duration(milliseconds: 500 + i * 250),
                        curve: Curves.elasticOut,
                        builder: (_, v, _) => Transform.scale(
                          scale: v,
                          child: Text(
                            i < stars! ? '⭐' : '☆',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (onNext != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text('다음 단계 ▶', maxLines: 1),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('다시', maxLines: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onMenu,
                      child: const Text('목록', maxLines: 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 위에서 떨어지는 별/꽃가루 이모지.
class _Confetti extends StatelessWidget {
  final AnimationController controller;
  const _Confetti({required this.controller});

  static const _emojis = ['⭐', '✨', '🎉', '💜', '🌟', '🍀'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => LayoutBuilder(
        builder: (_, c) {
          final rnd = math.Random(7);
          return Stack(
            children: [
              for (var i = 0; i < 22; i++)
                Builder(
                  builder: (_) {
                    final x = rnd.nextDouble();
                    final delay = rnd.nextDouble() * 0.4;
                    final speed = 0.7 + rnd.nextDouble() * 0.5;
                    final t = ((controller.value - delay) / (1 - delay)).clamp(
                      0.0,
                      1.0,
                    );
                    final sway = math.sin(t * 6 + i) * 18;
                    return Positioned(
                      left: x * (c.maxWidth - 24) + sway,
                      top: -24 + t * speed * (c.maxHeight + 24),
                      child: Opacity(
                        opacity: t == 0 ? 0 : (1 - t * t),
                        child: Transform.rotate(
                          angle: t * 8 + i,
                          child: Text(
                            _emojis[i % _emojis.length],
                            style: TextStyle(fontSize: 18 + (i % 3) * 6.0),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
