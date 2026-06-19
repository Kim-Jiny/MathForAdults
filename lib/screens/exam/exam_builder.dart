import '../../data/content_repository.dart';
import '../../models/difficulty.dart';
import '../../models/exam.dart';
import '../../models/math_problem.dart';

/// 프리셋 + 선택과목으로 모의수능 문항을 조립한다.
/// 공통(수Ⅰ+수Ⅱ)에서 common 스펙만큼, 선택 1과목에서 elective 스펙만큼 뽑는다.
/// 순서는 실제 수능처럼 공통 먼저, 선택 나중.
Future<List<MathProblem>> buildMockExam(
  ContentRepository repo, {
  required String elective,
  required ExamPreset preset,
}) async {
  final common = <MathProblem>[];
  for (final s in kCommonSubjects) {
    common.addAll(await repo.loadSubject(s));
  }
  final electivePool = await repo.loadSubject(elective);

  final commonPicks = _sample(common, preset.common);
  final electivePicks = _sample(electivePool, preset.elective);
  return [...commonPicks, ...electivePicks];
}

/// 배점 구간(2/3/4점)별로 지정 수만큼 무작위 추출. 부족하면 인접 구간에서 보충.
List<MathProblem> _sample(List<MathProblem> pool, TierSpec spec) {
  final byTier = <int, List<MathProblem>>{2: [], 3: [], 4: []};
  for (final p in pool) {
    byTier[p.difficulty.examPoints]!.add(p);
  }
  byTier.forEach((_, list) => list.shuffle());

  final used = <String>{};
  final result = <MathProblem>[];

  void take(int tier, int n) {
    var remaining = n;
    // 같은 구간 우선, 모자라면 가까운 구간 순으로
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
