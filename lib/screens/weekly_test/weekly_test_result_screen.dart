import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/math_problem.dart';
import '../../models/user_stats.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/math_text.dart';
import '../quiz/quiz_launcher.dart';

/// 주간시험 결과: 점수 + 지난주 대비 + 연속 응시 뱃지 + 오답 리뷰.
class WeeklyTestResultScreen extends ConsumerWidget {
  final List<MathProblem> problems;
  final Map<int, String> answers;

  const WeeklyTestResultScreen({
    super.key,
    required this.problems,
    required this.answers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);

    var correctCount = 0;
    final wrongProblems = <MathProblem>[];
    for (var i = 0; i < problems.length; i++) {
      final resp = (answers[i] ?? '').trim();
      final correct = resp.isNotEmpty && problems[i].isCorrect(resp);
      if (correct) {
        correctCount++;
      } else {
        wrongProblems.add(problems[i]);
      }
    }
    final total = problems.length;
    final accuracy = total == 0 ? 0.0 : correctCount / total;

    final history = [...stats.weeklyTestHistory]
      ..sort((a, b) => a.weekKey.compareTo(b.weekKey));
    WeeklyTestRecord? lastWeek;
    if (history.length > 1) {
      lastWeek = history[history.length - 2];
    }

    String? comparisonText;
    if (lastWeek != null && lastWeek.total > 0) {
      final lastAccuracy = lastWeek.correct / lastWeek.total;
      final diff = ((accuracy - lastAccuracy) * 100).round();
      if (diff > 0) {
        comparisonText = '지난주보다 정답률 +$diff%p 올랐어요';
      } else if (diff < 0) {
        comparisonText = '지난주보다 정답률 $diff%p';
      } else {
        comparisonText = '지난주와 정답률이 같아요';
      }
    }

    final streak = stats.weeklyTestStreak;

    return Scaffold(
      appBar: AppBar(
        title: const Text('이번 주 시험 결과'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            AppCard(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              child: Column(
                children: [
                  Text(
                    '$correctCount / $total',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '정답률 ${(accuracy * 100).round()}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (comparisonText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      comparisonText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (streak >= 2) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.streakOf(
                          theme.brightness,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$streak주 연속 응시 🔥',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.streakOf(theme.brightness),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (wrongProblems.isNotEmpty) ...[
              Text(
                '틀린 문제',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...wrongProblems.map((p) => _wrongTile(theme, p)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => QuizLauncher.startWith(
                    context,
                    wrongProblems,
                    title: '오답 다시 풀기',
                  ),
                  child: const Text('틀린 문제 다시 풀기'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('홈으로'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrongTile(ThemeData theme, MathProblem p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: AppColors.wrongOf(theme.brightness),
                ),
                const SizedBox(width: 6),
                Text(
                  p.lesson,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.wrongOf(theme.brightness),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MathText(p.question, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '정답  ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(child: MathText(p.correctAnswerDisplay)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: MathText(
                p.explanation,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
