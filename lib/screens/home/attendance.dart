import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

/// 홈 상단 출석 버튼. 탭하면 출석 달력 시트가 열린다.
class AttendanceButton extends ConsumerWidget {
  const AttendanceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(statsProvider);
    final today = StatsNotifier.dateKey(DateTime.now());
    final done = stats.attendance.contains(today);

    return Material(
      color: done
          ? scheme.surfaceContainerHighest
          : scheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showAttendanceSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.local_fire_department_rounded : Icons.event_available_rounded,
                  size: 16,
                  color: done ? const Color(0xFFE08A3C) : scheme.primary),
              const SizedBox(width: 5),
              Text(
                done ? '${stats.streakDays}일째' : '출석하기',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: done ? scheme.onSurface : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showAttendanceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AttendanceSheet(),
  );
}

class _AttendanceSheet extends ConsumerStatefulWidget {
  const _AttendanceSheet();

  @override
  ConsumerState<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends ConsumerState<_AttendanceSheet> {
  late DateTime _month; // 보이는 달의 1일

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = ref.watch(statsProvider);
    final attendance = stats.attendance;

    final now = DateTime.now();
    final todayKey = StatsNotifier.dateKey(now);
    final attendedToday = attendance.contains(todayKey);

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = _month.weekday % 7; // 일요일 시작(0)
    final monthCount = _monthAttendCount(attendance, _month.year, _month.month);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('출석',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE08A3C).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 15, color: Color(0xFFE08A3C)),
                      const SizedBox(width: 4),
                      Text('연속 ${stats.streakDays}일',
                          style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB96B22))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 월 이동
            Row(
              children: [
                IconButton(
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text('${_month.year}년 ${_month.month}월',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            const SizedBox(height: 4),
            Text('이번 달 $monthCount일 출석',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),

            // 요일 헤더
            Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),

            // 날짜 그리드
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _dayCell(theme, day, attendance, now),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: attendedToday
                    ? null
                    : () => ref.read(statsProvider.notifier).checkIn(now),
                icon: Icon(attendedToday
                    ? Icons.check_circle_rounded
                    : Icons.event_available_rounded),
                label: Text(attendedToday ? '오늘 출석 완료!' : '오늘 출석하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(
      ThemeData theme, int day, Set<String> attendance, DateTime now) {
    final scheme = theme.colorScheme;
    final date = DateTime(_month.year, _month.month, day);
    final attended = attendance.contains(StatsNotifier.dateKey(date));
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: attended ? scheme.primary : Colors.transparent,
        border: isToday && !attended
            ? Border.all(color: scheme.primary, width: 1.6)
            : null,
      ),
      child: Text(
        '$day',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: (attended || isToday) ? FontWeight.w800 : FontWeight.w500,
          color: attended
              ? scheme.onPrimary
              : isFuture
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                  : scheme.onSurface,
        ),
      ),
    );
  }

  int _monthAttendCount(Set<String> attendance, int year, int month) {
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    return attendance.where((d) => d.startsWith(prefix)).length;
  }
}
