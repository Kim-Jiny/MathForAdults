import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/exam_analysis.dart';
import '../../models/math_problem.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/math_text.dart';
import '../quiz/quiz_launcher.dart';
import 'exam_analysis_cards.dart';

/// 모의수능 결과 + 문항별 해설.
class ExamResultView extends StatelessWidget {
  final List<MathProblem> problems;
  final Map<int, String> answers;
  final Duration elapsed;
  final String title;

  const ExamResultView({
    super.key,
    required this.problems,
    required this.answers,
    required this.elapsed,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = ExamAnalysis.from(problems, answers);
    final score = a.score;
    final maxScore = a.maxScore;
    final correctCount = a.correctCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('모의수능 결과'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // 점수 요약
            AppCard(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              child: Column(
                children: [
                  Text('원점수',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('$score',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      )),
                  Text('만점 $maxScore점',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _mini(theme, '$correctCount / ${problems.length}', '정답'),
                      _mini(theme, '${(correctCount / problems.length * 100).round()}%',
                          '정답률'),
                      _mini(theme, _fmt(elapsed), '소요'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ExamAnalysisCards(
              analysis: a,
              onRetryWrong: () => QuizLauncher.startWith(
                context,
                a.wrongProblems,
                title: '오답 다시 풀기',
              ),
            ),
            const SizedBox(height: 24),
            Text('문항별 해설',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...List.generate(problems.length, (i) => _reviewTile(theme, i)),
            const SizedBox(height: 20),
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

  Widget _reviewTile(ThemeData theme, int i) {
    final p = problems[i];
    final resp = (answers[i] ?? '').trim();
    final answered = resp.isNotEmpty;
    final correct = answered && p.isCorrect(resp);
    final color = correct
        ? AppColors.correctOf(theme.brightness)
        : AppColors.wrongOf(theme.brightness);

    String myAnswer;
    if (!answered) {
      myAnswer = '미응답';
    } else if (p.type == ProblemType.short) {
      myAnswer = resp;
    } else {
      final idx = int.tryParse(resp);
      myAnswer = (idx != null && idx >= 0 && idx < p.choices.length)
          ? '${idx + 1}번'
          : resp;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: color),
                const SizedBox(width: 6),
                Text('${i + 1}번 · ${p.difficulty.examPoints}점',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800, color: color)),
                const Spacer(),
                Text(p.lesson,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            MathText(p.question, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 답  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: color)),
                Flexible(
                    child: Text(myAnswer,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(color: color))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('정답  ',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Expanded(child: MathText(p.correctAnswerDisplay)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: MathText(p.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(ThemeData theme, String v, String l) => Column(
        children: [
          Text(v,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(l,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(1000).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
