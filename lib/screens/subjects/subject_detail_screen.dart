import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum.dart';
import '../../models/curriculum_index.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/progress_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart' show kDisplayFont;
import 'chapter_lessons_screen.dart';
import 'subjects_screen.dart';

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
            children: [
              Text(
                '차근차근 한 단원씩 따라가 봐요 🐾',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < subject.chapters.length; i++)
                _PathRow(
                  number: i + 1,
                  isLast: i == subject.chapters.length - 1,
                  color: SubjectsScreen.colorFor(
                    kCurriculum.indexWhere((s) => s.name == subject.name),
                  ),
                  subject: subject,
                  chapter: subject.chapters[i],
                  idxChapter: idxSubject?.chapter(subject.chapters[i]),
                  solved: stats.solvedInChapter(
                    subject.name,
                    subject.chapters[i],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 학습 경로 한 칸: 왼쪽엔 번호 동그라미 + 이어지는 선, 오른쪽엔 단원 카드.
class _PathRow extends StatelessWidget {
  final int number;
  final bool isLast;
  final Color color;
  final Subject subject;
  final String chapter;
  final IdxChapter? idxChapter;
  final int solved;

  const _PathRow({
    required this.number,
    required this.isLast,
    required this.color,
    required this.subject,
    required this.chapter,
    required this.idxChapter,
    required this.solved,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = idxChapter?.count ?? 0;
    final done = total > 0 && solved >= total;
    final started = solved > 0;
    final ready = idxChapter != null;
    final nodeColor = !ready
        ? scheme.outlineVariant
        : done
        ? AppColors.correctOf(Theme.of(context).brightness)
        : started
        ? color
        : scheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor,
                        blurRadius: 0,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                  child: done
                      ? const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : Text(
                          '$number',
                          style: TextStyle(
                            fontFamily: kDisplayFont,
                            fontSize: 17,
                            color: (started && ready)
                                ? Colors.white
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _ChapterCard(
              subject: subject,
              chapter: chapter,
              idxChapter: idxChapter,
              solved: solved,
            ),
          ),
        ],
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
    final firstLessonDifficulties = ready && idxChapter!.lessons.isNotEmpty
        ? idxChapter!.lessons.first.difficulties
        : const [];
    final recommended = firstLessonDifficulties.isNotEmpty
        ? firstLessonDifficulties.first
        : ready && idxChapter!.difficulties.isNotEmpty
        ? idxChapter!.difficulties.first
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
                    subjectName: subject.name,
                    chapter: chapter,
                  ),
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
                  child: Text(
                    chapter,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ready ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (ready)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else
                  _comingSoon(theme),
              ],
            ),
            if (ready) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${idxChapter!.lessons.length}개 세부 단원 · 추천',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
                  Text(
                    '$solved / $total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    child: Text(
      '준비 중',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
