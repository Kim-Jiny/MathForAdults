import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum_index.dart';
import '../../models/difficulty.dart';
import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cute.dart';
import '../../widgets/mascot.dart';
import '../../widgets/math_backdrop.dart';
import '../../widgets/section_header.dart';
import '../../widgets/ads/banner_ad_slot.dart';
import '../../l10n/app_localizations.dart';
import '../exam/mock_exam_setup_screen.dart';
import '../game/sokoban_screen.dart';
import '../quiz/quiz_launcher.dart';
import '../weekly_test/weekly_test_launcher.dart';
import 'attendance.dart';

/// 오늘의 학습 대상 (인덱스에서 해석).
typedef Target = ({
  String subject,
  String chapter,
  String lesson,
  Difficulty difficulty,
  int count,
});

Target? _resolveTarget(CurriculumIndex index, ContinueInfo? cont) {
  IdxLesson? lessonOf(String s, String c, String l) =>
      index.chapter(s, c)?.lessons.where((x) => x.name == l).firstOrNull;

  if (cont != null) {
    final l = lessonOf(cont.subject, cont.chapter, cont.lesson);
    if (l != null && l.difficulties.isNotEmpty) {
      return (
        subject: cont.subject,
        chapter: cont.chapter,
        lesson: cont.lesson,
        difficulty: l.difficulties.first,
        count: l.count,
      );
    }
  }
  // 폴백: 인덱스의 첫 과목·단원·세부단원
  for (final s in index.subjects) {
    for (final c in s.chapters) {
      for (final l in c.lessons) {
        if (l.difficulties.isNotEmpty) {
          return (
            subject: s.name,
            chapter: c.name,
            lesson: l.name,
            difficulty: l.difficulties.first,
            count: l.count,
          );
        }
      }
    }
  }
  return null;
}

class HomeScreen extends ConsumerWidget {
  final void Function(int tabIndex) onOpenTab;
  const HomeScreen({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final wrongCount = ref.watch(wrongProblemsProvider).length;
    final indexAsync = ref.watch(curriculumIndexProvider);

    return Scaffold(
      body: SafeArea(
        child: indexAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('불러오기 실패: $e')),
          data: (index) {
            final target = _resolveTarget(index, stats.continueFrom);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const _Header(),
                const SizedBox(height: 18),
                if (target != null) _TodayCard(target: target),
                const SizedBox(height: 16),
                const _DailyGoalCard(),
                _ContinueCard(),
                const SizedBox(height: 22),
                const SectionHeader('바로 시작'),
                _QuickGrid(wrongCount: wrongCount, onOpenTab: onOpenTab),
                const SizedBox(height: 12),
                const _SokobanEntry(),
                const BannerAdSlot(placement: BannerPlacement.home),
                const SizedBox(height: 22),
                const SectionHeader('이번 주 기록'),
                const _WeeklyStats(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 상단: 앱 이름 + 출석 버튼, 그 아래 마스코트가 말풍선으로 말을 건다.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);
    final goal = ref.watch(settingsProvider.select((s) => s.dailyGoal));
    final solved = ref.watch(todaySolvedProvider);
    final streak = stats.currentStreak();
    final target = goal.target;
    final goalDone = target != null && solved >= target;

    final String line;
    final MascotMood mood;
    if (goalDone) {
      line = '오늘 목표 달성! 정말 대단해요';
      mood = MascotMood.cheer;
    } else if (solved > 0) {
      line = '좋아요, 이 기세로 한 문제만 더!';
      mood = MascotMood.happy;
    } else if (streak >= 2) {
      line = '$streak일째 이어가는 중이에요. 오늘도 한 문제만!';
      mood = MascotMood.happy;
    } else {
      line = AppLocalizations.of(context).homeGreeting;
      mood = MascotMood.happy;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).appName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 22,
              ),
            ),
            const Spacer(),
            const AttendanceButton(),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Mascot(size: 72, mood: mood, bounce: true),
            const SizedBox(width: 4),
            Expanded(
              child: SpeechBubble(
                child: Text(
                  line,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.35),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final Target target;
  const _TodayCard({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hero = Color.lerp(scheme.primary, AppColors.pink, 0.45)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(scheme.primary, Colors.black, 0.28)!,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, hero],
            ),
          ),
          child: Stack(
            children: [
              MathBackdrop(color: Colors.white, opacity: 0.24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _whitePill(Icons.wb_sunny_rounded, '오늘의 문제'),
                        const SizedBox(width: 8),
                        _whitePill(Icons.bolt_rounded, target.difficulty.label),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${target.subject} · ${target.chapter}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${target.lesson} · ${target.count}문제',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: scheme.primary,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: () => QuizLauncher.startLesson(
                          context,
                          ref,
                          subject: target.subject,
                          chapter: target.chapter,
                          lesson: target.lesson,
                          title: '오늘의 문제',
                        ),
                        child: const Text('문제 풀기 →'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whitePill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// 하루 목표: 별 N개를 채우는 방식. 자유 모드는 오늘 푼 문제 수만 표시.
class _DailyGoalCard extends ConsumerWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goal = ref.watch(settingsProvider.select((s) => s.dailyGoal));
    final solved = ref.watch(todaySolvedProvider);
    final target = goal.target;
    final done = target != null && solved >= target;
    const star = AppColors.sunny;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          if (target == null)
            const EmojiBadge('📝', color: AppColors.accent, size: 44)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < target; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      i < solved
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: target > 3 ? 30 : 36,
                      color: i < solved
                          ? star
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target == null
                      ? '오늘 $solved문제'
                      : done
                      ? '목표 달성!'
                      : '오늘 목표 $solved / $target',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  target == null
                      ? '편하게 풀어요'
                      : done
                      ? '별을 다 모았어요 🎉'
                      : '${target - solved}문제만 더!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);
    final c = stats.continueFrom;
    if (c == null) return const SizedBox.shrink();
    final chapterCount = ref
        .watch(curriculumIndexProvider)
        .valueOrNull
        ?.chapter(c.subject, c.chapter)
        ?.count;
    final progress = (chapterCount == null || chapterCount == 0)
        ? c.progress
        : (stats.solvedInChapter(c.subject, c.chapter) / chapterCount).clamp(
            0.0,
            1.0,
          );

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AppCard(
        onTap: () => QuizLauncher.startLesson(
          context,
          ref,
          subject: c.subject,
          chapter: c.chapter,
          lesson: c.lesson,
          title: '${c.lesson} 이어서',
        ),
        child: Row(
          children: [
            ProgressRing(
              value: progress,
              color: theme.colorScheme.primary,
              size: 56,
              child: const Text('📖', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이어서 풀기',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(c.lesson, style: theme.textTheme.titleSmall),
                  Text(
                    '${c.subject} · ${c.chapter}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 2×2 바로가기 타일: 수능 랜덤 / 모의수능 / 다시 풀기 / 주간시험.
class _QuickGrid extends ConsumerWidget {
  final int wrongCount;
  final void Function(int tabIndex) onOpenTab;
  const _QuickGrid({required this.wrongCount, required this.onOpenTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(statsProvider.select((s) => s.weeklySolved));
    const need = 5;
    final weeklyReady = weekly >= need;

    final tiles = <Widget>[
      PastelTile(
        emoji: '🎯',
        title: '수능 랜덤',
        subtitle: '배점 골라 무작위로',
        color: AppColors.streak,
        onTap: () => _pickCsat(context, ref),
      ),
      PastelTile(
        emoji: '⏱️',
        title: '모의수능',
        subtitle: '시간 재고 실전처럼',
        color: AppColors.accent,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MockExamSetupScreen())),
      ),
      PastelTile(
        emoji: '🔁',
        title: '다시 풀 문제',
        subtitle: wrongCount == 0 ? '아직 없어요, 좋아요!' : '$wrongCount문제 기다려요',
        color: AppColors.wrong,
        onTap: () => onOpenTab(2),
        badge: wrongCount == 0
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.wrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$wrongCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
      PastelTile(
        emoji: '🏆',
        title: '주간 시험',
        subtitle: weeklyReady ? '이번 주 복습 시험!' : '${need - weekly}문제 더 풀면 열려요',
        color: AppColors.sunny,
        onTap: weeklyReady
            ? () => WeeklyTestLauncher.start(context, ref)
            : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  /// 배점(2/3/4점) 선택 시트.
  void _pickCsat(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎯 수능 랜덤', style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '배점을 골라 전 과목에서 무작위로 풀어요',
                style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (pt, label, color) in [
                    (2, '가볍게', AppColors.accent),
                    (3, '적당히', AppColors.primary),
                    (4, '도전!', AppColors.wrong),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: pt == 4 ? 0 : 10),
                        child: PastelTile(
                          emoji: '$pt점',
                          title: label,
                          color: color,
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            QuizLauncher.startCsat(context, ref, pt);
                          },
                        ),
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

/// 미니게임(소코반) 진입 카드 — 새싹이가 상자를 밀며 논다.
class _SokobanEntry extends StatefulWidget {
  const _SokobanEntry();

  @override
  State<_SokobanEntry> createState() => _SokobanEntryState();
}

class _SokobanEntryState extends State<_SokobanEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Pastel.of(context, AppColors.primary);
    return AppCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SokobanMenuScreen())),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 56,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // 0~0.5: 오른쪽으로 상자를 밀고, 0.5~1: 제자리로 돌아온다.
                final t = _c.value;
                final push = t < 0.5
                    ? Curves.easeInOut.transform(t * 2)
                    : 1 - Curves.easeInOut.transform((t - 0.5) * 2);
                final hop = math.sin(t * math.pi * 6).abs() * 4;
                return Stack(
                  children: [
                    Positioned(
                      right: 2,
                      top: 6,
                      child: const Text('🌸', style: TextStyle(fontSize: 26)),
                    ),
                    Positioned(
                      left: 34 + push * 30,
                      top: 12,
                      child: const Text('🎁', style: TextStyle(fontSize: 30)),
                    ),
                    Positioned(
                      left: push * 30,
                      top: 6 - hop,
                      child: const Mascot(size: 40),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('상자 옮기기 게임', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '머리 식힐 겸 한 판! 소코반',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.fg),
        ],
      ),
    );
  }
}

/// 이번 주 기록: 이모지 칩 3개.
class _WeeklyStats extends ConsumerWidget {
  const _WeeklyStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(statsProvider);
    return Row(
      children: [
        Expanded(
          child: StatBubble(
            emoji: '📚',
            value: '${s.weeklySolved}',
            label: '이번 주',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBubble(
            emoji: '🎯',
            value: '${(s.accuracy * 100).round()}%',
            label: '정답률',
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBubble(
            emoji: '🔥',
            value: '${s.currentStreak()}일',
            label: '연속',
            color: AppColors.streak,
          ),
        ),
      ],
    );
  }
}
