import 'difficulty.dart';
import 'exam.dart';
import 'math_problem.dart';

/// 모의수능 한 회차의 결과를 분석한 집계값.
///
/// [problems]와 응답 맵([answers]: 문항 index → 응답 문자열)으로부터
/// 점수·배점별·영역별(공통/선택)·단원별 통계를 한 번에 계산한다.
/// 순수 계산만 담당해 위젯과 분리(테스트 용이).
class ExamAnalysis {
  final int score;
  final int maxScore;
  final int correctCount;
  final int totalCount;

  /// 배점(2/3/4점)별 통계. 시험에 등장한 배점만, 오름차순.
  final List<TierStat> tiers;

  /// 공통(수Ⅰ·수Ⅱ) 영역 통계.
  final SectionStat common;

  /// 선택(확통/미적분/기하 등) 영역 통계.
  final SectionStat elective;

  /// 오답이 있는 단원, 오답 수 내림차순.
  final List<LessonStat> wrongLessons;

  /// 과목별 오답 수(오답 있는 과목만).
  final Map<String, int> wrongBySubject;

  /// 틀렸거나 미응답한 문제(다시 풀기용). 원래 출제 순서 유지.
  final List<MathProblem> wrongProblems;

  const ExamAnalysis({
    required this.score,
    required this.maxScore,
    required this.correctCount,
    required this.totalCount,
    required this.tiers,
    required this.common,
    required this.elective,
    required this.wrongLessons,
    required this.wrongBySubject,
    required this.wrongProblems,
  });

  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;

  /// 복습 추천 단원(가장 많이 틀린 순 최대 3개).
  List<LessonStat> get reviewRecommendations => wrongLessons.take(3).toList();

  factory ExamAnalysis.from(
    List<MathProblem> problems,
    Map<int, String> answers,
  ) {
    var score = 0;
    var maxScore = 0;
    var correctCount = 0;

    final tierAgg = <int, _Counter>{};
    final commonAgg = _SectionCounter();
    final electiveAgg = _SectionCounter();
    final lessonAgg = <String, _LessonCounter>{};
    final wrongBySubject = <String, int>{};
    final wrongProblems = <MathProblem>[];

    for (var i = 0; i < problems.length; i++) {
      final p = problems[i];
      final pts = p.difficulty.examPoints;
      final resp = (answers[i] ?? '').trim();
      final correct = resp.isNotEmpty && p.isCorrect(resp);

      maxScore += pts;
      if (correct) {
        score += pts;
        correctCount++;
      } else {
        wrongProblems.add(p);
        wrongBySubject.update(p.subject, (v) => v + 1, ifAbsent: () => 1);
      }

      (tierAgg[pts] ??= _Counter()).add(correct);

      final section = kCommonSubjects.contains(p.subject)
          ? commonAgg
          : electiveAgg;
      section.add(pts: pts, correct: correct);

      final key = '${p.subject}|${p.chapter}|${p.lesson}';
      (lessonAgg[key] ??= _LessonCounter(p.subject, p.chapter, p.lesson))
          .add(correct);
    }

    final tiers =
        (tierAgg.entries.map((e) => TierStat(e.key, e.value.correct, e.value.total)).toList())
          ..sort((a, b) => a.points.compareTo(b.points));

    final wrongLessons =
        lessonAgg.values
            .where((c) => c.wrong > 0)
            .map((c) => LessonStat(c.subject, c.chapter, c.lesson, c.wrong, c.total))
            .toList()
          ..sort((a, b) {
            final byWrong = b.wrong.compareTo(a.wrong);
            return byWrong != 0 ? byWrong : b.total.compareTo(a.total);
          });

    return ExamAnalysis(
      score: score,
      maxScore: maxScore,
      correctCount: correctCount,
      totalCount: problems.length,
      tiers: tiers,
      common: commonAgg.toStat(),
      elective: electiveAgg.toStat(),
      wrongLessons: wrongLessons,
      wrongBySubject: wrongBySubject,
      wrongProblems: wrongProblems,
    );
  }
}

/// 배점 한 구간(2/3/4점)의 정답 통계.
class TierStat {
  final int points;
  final int correct;
  final int total;
  const TierStat(this.points, this.correct, this.total);

  double get accuracy => total == 0 ? 0 : correct / total;
}

/// 영역(공통/선택)의 점수·정답 통계.
class SectionStat {
  final int scoreGot;
  final int scoreMax;
  final int correct;
  final int total;
  const SectionStat({
    required this.scoreGot,
    required this.scoreMax,
    required this.correct,
    required this.total,
  });

  double get rate => scoreMax == 0 ? 0 : scoreGot / scoreMax;
  bool get isEmpty => total == 0;
}

/// 단원 한 개의 오답 통계.
class LessonStat {
  final String subject;
  final String chapter;
  final String lesson;
  final int wrong;
  final int total;
  const LessonStat(
    this.subject,
    this.chapter,
    this.lesson,
    this.wrong,
    this.total,
  );
}

class _Counter {
  int correct = 0;
  int total = 0;
  void add(bool ok) {
    total++;
    if (ok) correct++;
  }
}

class _SectionCounter {
  int scoreGot = 0;
  int scoreMax = 0;
  int correct = 0;
  int total = 0;
  void add({required int pts, required bool correct}) {
    total++;
    scoreMax += pts;
    if (correct) {
      this.correct++;
      scoreGot += pts;
    }
  }

  SectionStat toStat() => SectionStat(
    scoreGot: scoreGot,
    scoreMax: scoreMax,
    correct: correct,
    total: total,
  );
}

class _LessonCounter {
  final String subject;
  final String chapter;
  final String lesson;
  int wrong = 0;
  int total = 0;
  _LessonCounter(this.subject, this.chapter, this.lesson);
  void add(bool ok) {
    total++;
    if (!ok) wrong++;
  }
}
