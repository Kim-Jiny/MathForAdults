import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/cute.dart';
import '../../models/curriculum.dart';
import '../../widgets/ads/banner_ad_slot.dart';

/// 기록 탭: 요약 통계 + 과목별 진행률 + 약한 단원 + 최근 기록.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(statsProvider);
    final progress = ref.watch(subjectProgressProvider);
    final progressEntries = progress.entries.toList();
    // 약한 과목: 한 문제라도 푼 경우, 진행률이 가장 낮은 과목.
    String? weakest;
    if (s.totalSolved > 0 && progressEntries.isNotEmpty) {
      weakest =
          (progressEntries.toList()..sort((a, b) => a.value.compareTo(b.value)))
              .first
              .key;
    }
    // 최신 주가 앞에 오도록 정렬(최대 8건).
    final weeklyTestRows = ([
      ...s.weeklyTestHistory,
    ]..sort((a, b) => b.weekKey.compareTo(a.weekKey))).take(8).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('내 기록')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // 요약: 이모지 말풍선 칩
          Row(
            children: [
              Expanded(
                child: StatBubble(
                  emoji: '📝',
                  value: '${s.totalSolved}',
                  label: '푼 문제',
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
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatBubble(
                  emoji: '📅',
                  value: '${s.weeklySolved}',
                  label: '이번 주 푼 문제',
                  color: const Color(0xFF4DA8E8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBubble(
                  emoji: '🌱',
                  value: weakest ?? '-',
                  label: '가장 덜 푼 과목',
                  color: AppColors.wrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 과목별 진행률
          const SectionHeader('과목별 진행률'),
          AppCard(
            child: progressEntries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '아직 푼 문제가 없어요. 한 문제부터 시작해 볼까요?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < progressEntries.length; i++) ...[
                        _subjectRow(
                          theme,
                          progressEntries[i].key,
                          progressEntries[i].value,
                        ),
                        if (i != progressEntries.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // 주간시험 기록
          if (weeklyTestRows.isNotEmpty) ...[
            const SectionHeader('주간시험 기록'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < weeklyTestRows.length; i++) ...[
                    _weeklyTestRow(
                      theme,
                      weeklyTestRows[i],
                      i + 1 < weeklyTestRows.length
                          ? weeklyTestRows[i + 1]
                          : null,
                    ),
                    if (i != weeklyTestRows.length - 1)
                      Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: theme.colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 최근 풀이 기록
          const BannerAdSlot(
            placement: BannerPlacement.stats,
            margin: EdgeInsets.only(bottom: 12),
          ),
          const SectionHeader('최근 풀이 기록'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < s.recent.length; i++) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    leading: Icon(
                      s.recent[i].correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: s.recent[i].correct
                          ? AppColors.correctOf(theme.brightness)
                          : AppColors.wrongOf(theme.brightness),
                    ),
                    title: Text(
                      '${s.recent[i].subject} · ${s.recent[i].lesson}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      _recentDateLabel(s.recent[i]),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (i != s.recent.length - 1)
                    Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: theme.colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectRow(ThemeData theme, String name, double v) {
    final i = kCurriculum.indexWhere((x) => x.name == name);
    final emoji = i < 0 ? '📚' : kCurriculum[i].emoji;
    final color = AppColors.difficultyColors[(i < 0 ? 0 : i) % 6];
    return Row(
      children: [
        EmojiBadge(emoji, color: color, size: 38),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ProgressBar(value: v, color: color),
        ),
      ],
    );
  }

  Widget _weeklyTestRow(
    ThemeData theme,
    WeeklyTestRecord r,
    WeeklyTestRecord? prev,
  ) {
    final acc = r.total == 0 ? 0 : (r.correct / r.total * 100).round();
    String? delta;
    IconData? deltaIcon;
    Color? deltaColor;
    if (prev != null && prev.total > 0) {
      final prevAcc = prev.correct / prev.total * 100;
      final diff = (acc - prevAcc).round();
      if (diff > 0) {
        delta = '+$diff%p';
        deltaIcon = Icons.trending_up_rounded;
        deltaColor = AppColors.correctOf(theme.brightness);
      } else if (diff < 0) {
        delta = '$diff%p';
        deltaIcon = Icons.trending_down_rounded;
        deltaColor = AppColors.wrongOf(theme.brightness);
      }
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: const Icon(Icons.quiz_rounded),
      title: Text(
        '${r.correct}/${r.total}문제 · $acc%',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_weekLabel(r.weekKey)),
      trailing: delta == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(deltaIcon, size: 16, color: deltaColor),
                const SizedBox(width: 2),
                Text(
                  delta,
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  String _weekLabel(String weekKey) {
    final d = DateTime.tryParse(weekKey);
    if (d == null) return weekKey;
    return '${d.month}/${d.day} 주';
  }

  String _recentDateLabel(RecentRecord record) {
    final key = record.dateKey;
    if (key == null || key.isEmpty) return record.dateLabel;
    final today = DateTime.now();
    final todayKey = StatsNotifier.dateKey(today);
    if (key == todayKey) return '오늘';
    final yesterdayKey = StatsNotifier.dateKey(
      today.subtract(const Duration(days: 1)),
    );
    if (key == yesterdayKey) return '어제';
    final parsed = DateTime.tryParse(key);
    if (parsed == null) return record.dateLabel;
    return '${parsed.month}/${parsed.day}';
  }
}
