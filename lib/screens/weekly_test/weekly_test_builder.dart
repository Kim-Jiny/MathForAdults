import 'dart:math';

import '../../data/content_repository.dart';
import '../../models/math_problem.dart';

/// 이번 주 학습한 레슨의 새 문제 위주 + 지난 주간시험에서 틀려 이월된 문제
/// 일부를 섞어 주간시험 문제를 구성한다. 학습량이 부족하면(3개 미만) 빈 리스트를 반환한다.
Future<List<MathProblem>> buildWeeklyTest(
  ContentRepository repo, {
  required Set<String> lessonKeys, // "과목|단원|세부단원"
  required Set<String> solvedIds,
  required List<MathProblem> reviewPool, // 이월된 주간시험 오답 후보
  int targetCount = 6,
  int maxReview = 2,
}) async {
  final reviewPicks = ([...reviewPool]..shuffle())
      .take(min(maxReview, targetCount))
      .toList();
  final reviewIds = reviewPicks.map((p) => p.id).toSet();

  final newTarget = targetCount - reviewPicks.length;
  final lessonPools = <List<MathProblem>>[];
  for (final key in lessonKeys) {
    final parts = key.split('|');
    if (parts.length != 3) continue;
    final problems = await repo.loadLesson(parts[0], parts[1], parts[2]);
    final pool = problems
        .where((p) => !solvedIds.contains(p.id) && !reviewIds.contains(p.id))
        .toList()
      ..shuffle();
    if (pool.isNotEmpty) lessonPools.add(pool);
  }
  lessonPools.shuffle();

  // 레슨당 라운드로빈으로 1문제씩 뽑아 다양성을 확보한다.
  final newPicks = <MathProblem>[];
  final usedIds = <String>{};
  var round = 0;
  while (newPicks.length < newTarget && lessonPools.isNotEmpty) {
    var addedThisRound = false;
    for (final pool in lessonPools) {
      if (newPicks.length >= newTarget) break;
      if (round >= pool.length) continue;
      final p = pool[round];
      if (usedIds.add(p.id)) {
        newPicks.add(p);
        addedThisRound = true;
      }
    }
    if (!addedThisRound) break;
    round++;
  }

  final result = [...newPicks, ...reviewPicks]..shuffle();
  return result.length >= 3 ? result : const [];
}
