import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum.dart';
import '../../models/curriculum_index.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/progress_bar.dart';
import 'chapter_lessons_screen.dart';

/// 과목 상세: 단원(chapter) 목록 + 단원별 진행률/추천 난이도.
class SubjectDetailScreen extends ConsumerWidget {
  final Subject subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexAsync = ref.watch(curriculumIndexProvider);
    final stats = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('${subject.emoji} ${subject.name}')),
      body: indexAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (index) {
          final idxSubject = index.subject(subject.name);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: subject.chapters.map((chapter) {
              final idxChapter = idxSubject?.chapter(chapter);
              return _ChapterCard(
                subject: subject,
                chapter: chapter,
                idxChapter: idxChapter,
                solved: stats.solvedInChapter(subject.name, chapter),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Subject subject;
  final String chapter;
  final IdxChapter? idxChapter;
  final int solved;

  const _ChapterCard({
    required this.subject,
    required this.chapter,
    required this.idxChapter,
    required this.solved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = idxChapter != null;
    final recommended = ready && idxChapter!.difficulties.isNotEmpty
        ? (idxChapter!.lessons.first.difficulties.isNotEmpty
            ? idxChapter!.lessons.first.difficulties.first
            : idxChapter!.difficulties.first)
        : null;
    final total = idxChapter?.count ?? 0;
    final p = total == 0 ? 0.0 : (solved / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: ready
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChapterLessonsScreen(
                        subjectName: subject.name, chapter: chapter),
                  ),
                )
            : null,
        color: ready ? null : theme.colorScheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(chapter,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color:
                            ready ? null : theme.colorScheme.onSurfaceVariant,
                      )),
                ),
                if (ready)
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant)
                else
                  _comingSoon(theme),
              ],
            ),
            if (ready) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('${idxChapter!.lessons.length}개 세부 단원 · 추천',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  if (recommended != null)
                    DifficultyBadge(recommended, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ProgressBar(value: p)),
                  const SizedBox(width: 10),
                  Text('$solved / $total',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _comingSoon(ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('준비 중',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
}
