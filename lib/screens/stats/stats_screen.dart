import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('내 기록')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // 요약 4분할
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatTile(value: '${s.totalSolved}', label: '푼 문제'),
                _vline(theme),
                StatTile(value: '${(s.accuracy * 100).round()}%', label: '정답률'),
                _vline(theme),
                StatTile(value: '${s.streakDays}일', label: '연속'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: StatTile(
                    icon: Icons.calendar_today_rounded,
                    value: '${s.weeklySolved}',
                    label: '이번 주 푼 문제',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: StatTile(
                    icon: Icons.flag_rounded,
                    value: weakest ?? '-',
                    label: '약한 단원',
                    valueColor: AppColors.wrongOf(theme.brightness),
                  ),
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

  Widget _subjectRow(ThemeData theme, String name, double v) => Row(
    children: [
      SizedBox(
        width: 96,
        child: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: ProgressBar(value: v)),
    ],
  );

  Widget _vline(ThemeData theme) =>
      Container(width: 1, height: 36, color: theme.colorScheme.outlineVariant);

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
