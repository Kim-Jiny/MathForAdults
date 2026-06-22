import '../../data/content_repository.dart';
import '../../models/difficulty.dart';
import '../../models/exam.dart';
import '../../models/math_problem.dart';

/// 프리셋 + 선택과목으로 모의수능 문항을 조립한다.
/// 공통(수Ⅰ+수Ⅱ)에서 common 스펙만큼, 선택 1과목에서 elective 스펙만큼 뽑는다.
/// 순서는 실제 수능처럼 공통 먼저, 선택 나중.
/// [seen]에 든 문제(이미 푼 문제)는 뒤로 미뤄 '안 푼 문제'를 우선 출제한다.
Future<List<MathProblem>> buildMockExam(
  ContentRepository repo, {
  required String elective,
  required ExamPreset preset,
  Set<String> seen = const {},
}) async {
  final common = <MathProblem>[];
  for (final s in kCommonSubjects) {
    common.addAll(await repo.loadSubject(s));
  }
  final electivePool = await repo.loadSubject(elective);

  final commonPicks = _sample(common, preset.common, seen);
  final electivePicks = _sample(electivePool, preset.elective, seen);
  return [...commonPicks, ...electivePicks];
}

/// 배점 구간(2/3/4점)별로 지정 수만큼 추출. 각 구간에서 '안 푼 문제' 먼저,
/// 모자라면 푼 문제로 보충. 그래도 부족하면 인접 구간에서 보충.
List<MathProblem> _sample(
    List<MathProblem> pool, TierSpec spec, Set<String> seen) {
  final byTier = <int, List<MathProblem>>{2: [], 3: [], 4: []};
  for (final p in pool) {
    byTier[p.difficulty.examPoints]!.add(p);
  }
  // 각 구간: 무작위 섞은 뒤 '안 푼 문제'를 앞으로 (안 푼 것 우선 출제).
  byTier.forEach((_, list) {
    list.shuffle();
    list.sort((a, b) =>
        (seen.contains(a.id) ? 1 : 0) - (seen.contains(b.id) ? 1 : 0));
  });

  final used = <String>{};
  final result = <MathProblem>[];

  void take(int tier, int n) {
    var remaining = n;
    for (final t in [tier, tier - 1, tier + 1, tier - 2, tier + 2]) {
      final list = byTier[t];
      if (list == null) continue;
      for (final p in list) {
        if (remaining == 0) break;
        if (used.add(p.id)) {
          result.add(p);
          remaining--;
        }
      }
      if (remaining == 0) break;
    }
  }

  take(2, spec.two);
  take(3, spec.three);
  take(4, spec.four);
  return result;
}
