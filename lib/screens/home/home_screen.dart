import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum_index.dart';
import '../../models/difficulty.dart';
import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/math_backdrop.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/ads/banner_ad_slot.dart';
import '../../l10n/app_localizations.dart';
import '../exam/mock_exam_setup_screen.dart';
import '../quiz/quiz_launcher.dart';
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
    final theme = Theme.of(context);
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
                Row(
                  children: [
                    Text(AppLocalizations.of(context).appName,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const AttendanceButton(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context).homeGreeting,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                if (target != null) _TodayCard(target: target),
                const SizedBox(height: 20),
                const SectionHeader('이어서 / 도전'),
                _ContinueCard(),
                const SizedBox(height: 12),
                _CsatRandomCard(),
                const SizedBox(height: 12),
                _MockExamCard(),
                const SizedBox(height: 12),
                _ReviewCard(count: wrongCount, onTap: () => onOpenTab(2)),
                const BannerAdSlot(placement: BannerPlacement.home),
                const SizedBox(height: 20),
                const SectionHeader('이번 주 기록'),
                _WeeklyCard(),
              ],
            );
          },
        ),
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  Color.lerp(scheme.primary, scheme.secondary, 0.55)!,
                ],
              ),
            ),
            child: SizedBox(
              height: 196,
              width: double.infinity,
              child: Stack(
                children: [
                  MathBackdrop(color: Colors.white, opacity: 0.10),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text('오늘의 문제',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${target.subject} · ${target.chapter}',
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(target.lesson,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92))),
                        const Spacer(),
                        Row(
                          children: [
                            DifficultyBadge(target.difficulty, compact: true),
                            const SizedBox(width: 8),
                            _whitePill(Icons.list_alt, '${target.count}문제'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: scheme.primary,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: () => QuizLauncher.startLesson(
                context,
                ref,
                subject: target.subject,
                chapter: target.chapter,
                lesson: target.lesson,
                title: '오늘의 문제',
              ),
              child: const Text('문제 풀기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whitePill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ContinueCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = ref.watch(statsProvider).continueFrom;
    if (c == null) return const SizedBox.shrink();

    return AppCard(
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이어 풀던 단원',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text('${c.subject} > ${c.chapter} > ${c.lesson}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ProgressBar(value: c.progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CsatRandomCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('수능 랜덤',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text('배점을 골라 전 과목에서 무작위로 풀어요',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(
            children: [2, 3, 4].map((pt) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: pt == 4 ? 0 : 10),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => QuizLauncher.startCsat(context, ref, pt),
                    child: Text('$pt점',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MockExamCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MockExamSetupScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.timer_outlined, color: scheme.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('모의수능 보기',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('공통 + 선택 1과목, 시간 재고 실전처럼',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ReviewCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFD66A5F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFFD66A5F)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다시 풀 문제',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(count == 0 ? '아직 없어요, 좋아요!' : '$count문제가 기다리고 있어요',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _WeeklyCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(statsProvider);
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _mini(theme, '${s.weeklySolved}', '이번 주'),
          _divider(theme),
          _mini(theme, '${(s.accuracy * 100).round()}%', '정답률'),
          _divider(theme),
          _mini(theme, '${s.streakDays}일', '연속'),
        ],
      ),
    );
  }

  Widget _mini(ThemeData theme, String v, String l) => Column(
        children: [
          Text(v,
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary)),
          const SizedBox(height: 2),
          Text(l,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _divider(ThemeData theme) =>
      Container(width: 1, height: 34, color: theme.colorScheme.outlineVariant);
}
