import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/concept_card.dart';
import '../../models/curriculum_index.dart';
import '../../models/difficulty.dart';
import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/concept_sheet.dart';
import '../../widgets/difficulty_badge.dart';
import '../quiz/quiz_launcher.dart';

/// 단원 상세: 세부 단원(lesson) 목록 → 난이도 선택 → 풀이 진입.
class ChapterLessonsScreen extends ConsumerWidget {
  final String subjectName;
  final String chapter;
  const ChapterLessonsScreen({
    super.key,
    required this.subjectName,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexAsync = ref.watch(curriculumIndexProvider);
    ref.watch(conceptsProvider); // 개념 카드 선로드
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(chapter)),
      body: indexAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (index) {
          final idxChapter = index.chapter(subjectName, chapter);
          final lessons = idxChapter?.lessons ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(
                '세부 단원을 고르면 난이도를 선택할 수 있어요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...lessons.map(
                (lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: lesson.difficulties.isEmpty
                        ? null
                        : () => _openDifficultySheet(context, ref, lesson),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lesson.count}문제 · 난이도 ${lesson.difficulties.length}단계',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (lesson.difficulties.isEmpty)
                          Text(
                            '준비 중',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDifficultySheet(
    BuildContext context,
    WidgetRef ref,
    IdxLesson lesson,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '난이도를 골라 시작하세요',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (_) {
                    final concept =
                        ref
                            .read(conceptsProvider)
                            .valueOrNull?[ConceptCard.keyOf(
                          subjectName,
                          chapter,
                          lesson.name,
                        )];
                    if (concept == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: () => showConceptSheet(context, concept),
                        icon: const Text('📘', style: TextStyle(fontSize: 16)),
                        label: const Text('개념 카드 먼저 보기'),
                      ),
                    );
                  },
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: lesson.difficulties
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: d.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.of(sheetCtx).pop();
                                  ref
                                      .read(statsProvider.notifier)
                                      .setContinue(
                                        ContinueInfo(
                                          subject: subjectName,
                                          chapter: chapter,
                                          lesson: lesson.name,
                                          progress: 0.1,
                                        ),
                                      );
                                  QuizLauncher.startLesson(
                                    context,
                                    ref,
                                    subject: subjectName,
                                    chapter: chapter,
                                    lesson: lesson.name,
                                    difficulty: d,
                                    title: '${lesson.name} · ${d.label}',
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      DifficultyBadge(d),
                                      const Spacer(),
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: d.color,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
