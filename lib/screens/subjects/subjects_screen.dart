import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cute.dart';
import '../../widgets/ads/banner_ad_slot.dart';
import 'subject_detail_screen.dart';

/// 단원 탭: 과목 목록.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  static Color colorFor(int i) => [
    AppColors.accent,
    AppColors.primary,
    const Color(0xFF4DA8E8),
    const Color(0xFFC26BE0),
    AppColors.streak,
    AppColors.wrong,
    AppColors.pink,
  ][i % 7];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(subjectProgressProvider);
    final theme = Theme.of(context);

    Widget grid(List<int> idx) => LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final i in idx)
              SizedBox(
                width: w,
                child: _SubjectCard(
                  subject: kCurriculum[i],
                  color: colorFor(i),
                  progress: progress[kCurriculum[i].name] ?? 0,
                ),
              ),
          ],
        );
      },
    );

    final all = List.generate(kCurriculum.length, (i) => i);
    return Scaffold(
      appBar: AppBar(title: const Text('단원 선택')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            '어디서부터 풀어볼까요? 🗺️',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // 앞의 두 과목 다음에 배너 1개.
          grid(all.take(2).toList()),
          const SizedBox(height: 12),
          const BannerAdSlot(
            placement: BannerPlacement.subjects,
            margin: EdgeInsets.only(bottom: 12),
          ),
          grid(all.skip(2).toList()),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final Color color;
  final double progress;
  const _SubjectCard({
    required this.subject,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Pastel.of(context, color);
    final radius = BorderRadius.circular(24);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: p.border, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Color.alphaBlend(p.bg, theme.colorScheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubjectDetailScreen(subject: subject),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
              children: [
                ProgressRing(
                  value: progress,
                  color: color,
                  size: 76,
                  child: Text(
                    subject.emoji,
                    style: const TextStyle(fontSize: 30, height: 1),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subject.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: p.fg),
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.chapters.length}개 단원 · ${(progress * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
