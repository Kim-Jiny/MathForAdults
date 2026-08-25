import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import 'weekly_test_builder.dart';
import 'weekly_test_screen.dart';

/// 주간시험 시작 헬퍼. 이번 주 학습 기록을 바탕으로 문제를 구성한 뒤 push.
class WeeklyTestLauncher {
  WeeklyTestLauncher._();

  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final stats = ref.read(statsProvider);
    final repo = ref.read(contentRepositoryProvider);
    final reviewPool = stats.weeklyTestWrong.values.toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    List<MathProblem> problems;
    try {
      problems = await buildWeeklyTest(
        repo,
        lessonKeys: stats.weeklyLessonKeys,
        solvedIds: stats.solvedIds,
        reviewPool: reviewPool,
      );
    } catch (_) {
      problems = const [];
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!context.mounted) return;

    if (problems.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이번 주 학습이 더 필요해요'),
          content: const Text('문제를 몇 개 더 풀면 주간시험이 준비돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WeeklyTestScreen(problems: problems)),
    );
  }
}
