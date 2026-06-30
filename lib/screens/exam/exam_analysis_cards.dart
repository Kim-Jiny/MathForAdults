import 'package:flutter/material.dart';

import '../../models/exam_analysis.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';

/// 모의수능 결과 분석 카드 묶음.
/// 배점별 정답률 · 공통/선택 영역 점수 · 복습 추천 + 틀린 문제 다시 풀기.
class ExamAnalysisCards extends StatelessWidget {
  final ExamAnalysis analysis;
  final VoidCallback onRetryWrong;

  const ExamAnalysisCards({
    super.key,
    required this.analysis,
    required this.onRetryWrong,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = analysis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('배점별 정답률'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < a.tiers.length; i++) ...[
                if (i != 0) const SizedBox(height: 14),
                _tierRow(theme, a.tiers[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        const SectionHeader('영역별 점수'),
        Row(
          children: [
            Expanded(child: _sectionCard(theme, '공통', '수Ⅰ·수Ⅱ', a.common)),
            const SizedBox(width: 12),
            Expanded(child: _sectionCard(theme, '선택', '선택 과목', a.elective)),
          ],
        ),
        const SizedBox(height: 20),

        const SectionHeader('복습 추천'),
        AppCard(
          child: a.wrongLessons.isEmpty
              ? _allCorrect(theme)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가장 많이 틀린 단원부터 다시 보면 좋아요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final l in a.reviewRecommendations) ...[
                      _lessonRow(theme, l),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: onRetryWrong,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          '틀린 문제 ${a.wrongProblems.length}개 다시 풀기',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tierRow(ThemeData theme, TierStat t) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '${t.points}점',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ProgressBar(
            value: t.accuracy,
            color: _rateColor(theme, t.accuracy),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${t.correct}/${t.total}',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(ThemeData theme, String title, String sub, SectionStat s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            sub,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (s.isEmpty)
            Text(
              '-',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${s.scoreGot}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '/ ${s.scoreMax}점',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(
              value: s.rate,
              showPercent: false,
              color: _rateColor(theme, s.rate),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lessonRow(ThemeData theme, LessonStat l) {
    final wrongColor = AppColors.wrongOf(theme.brightness);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.lesson,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${l.subject} › ${l.chapter}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: wrongColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '오답 ${l.wrong}/${l.total}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: wrongColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _allCorrect(ThemeData theme) {
    final c = AppColors.correctOf(theme.brightness);
    return Row(
      children: [
        Icon(Icons.emoji_events_rounded, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '모든 문제를 맞혔어요. 완벽합니다!',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// 정답률에 따른 색(낮음=빨강, 중간=주황, 높음=초록).
  Color _rateColor(ThemeData theme, double rate) {
    if (rate >= 0.7) return AppColors.correctOf(theme.brightness);
    if (rate >= 0.4) return AppColors.streakOf(theme.brightness);
    return AppColors.wrongOf(theme.brightness);
  }
}
