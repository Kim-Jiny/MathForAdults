import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';

/// 기록 탭: 요약 통계 + 과목별 진행률 + 약한 단원 + 최근 기록.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(statsProvider);

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
                StatTile(
                    value: '${(s.accuracy * 100).round()}%', label: '정답률'),
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
                    value: s.weakestSubject ?? '-',
                    label: '약한 단원',
                    valueColor: const Color(0xFFD66A5F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 과목별 진행률
          const SectionHeader('과목별 진행률'),
          AppCard(
            child: Column(
              children: [
                for (final e in s.subjectProgress.entries) ...[
                  _subjectRow(theme, e.key, e.value),
                  if (e.key != s.subjectProgress.keys.last)
                    const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 최근 풀이 기록
          const SectionHeader('최근 풀이 기록'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < s.recent.length; i++) ...[
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    leading: Icon(
                      s.recent[i].correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: s.recent[i].correct
                          ? const Color(0xFF2E9E6B)
                          : const Color(0xFFD66A5F),
                    ),
                    title: Text('${s.recent[i].subject} · ${s.recent[i].lesson}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(s.recent[i].dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  if (i != s.recent.length - 1)
                    Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: theme.colorScheme.outlineVariant),
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
            child: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(child: ProgressBar(value: v)),
        ],
      );

  Widget _vline(ThemeData theme) =>
      Container(width: 1, height: 36, color: theme.colorScheme.outlineVariant);
}
