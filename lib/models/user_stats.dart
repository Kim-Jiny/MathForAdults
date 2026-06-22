import 'math_problem.dart';

/// 이어서 풀 위치
class ContinueInfo {
  final String subject;
  final String chapter;
  final String lesson;
  final double progress; // 0..1

  const ContinueInfo({
    required this.subject,
    required this.chapter,
    required this.lesson,
    required this.progress,
  });

  factory ContinueInfo.fromJson(Map<String, dynamic> j) => ContinueInfo(
        subject: j['subject'] as String,
        chapter: j['chapter'] as String,
        lesson: j['lesson'] as String,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'chapter': chapter,
        'lesson': lesson,
        'progress': progress,
      };
}

/// 최근 풀이 기록 한 줄
class RecentRecord {
  final String problemId;
  final String subject;
  final String lesson;
  final bool correct;
  final String dateLabel;

  const RecentRecord({
    required this.problemId,
    required this.subject,
    required this.lesson,
    required this.correct,
    required this.dateLabel,
  });

  factory RecentRecord.fromJson(Map<String, dynamic> j) => RecentRecord(
        problemId: j['problemId'] as String,
        subject: j['subject'] as String,
        lesson: j['lesson'] as String,
        correct: j['correct'] as bool? ?? false,
        dateLabel: j['dateLabel'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'problemId': problemId,
        'subject': subject,
        'lesson': lesson,
        'correct': correct,
        'dateLabel': dateLabel,
      };
}

/// 사용자 학습 상태. 로컬에 영속화된다.
class UserStats {
  final int totalSolved;
  final int totalCorrect;
  final int streakDays;
  final int weeklySolved;
  final Map<String, MathProblem> wrongProblems; // 다시 풀 문제 (객체 보관)
  final Map<String, int> solvedByChapter; // "과목|단원" → 푼 문제 수(고유)
  final ContinueInfo? continueFrom;
  final List<RecentRecord> recent;
  final Set<String> attendance; // 출석한 날짜 'yyyy-MM-dd'
  final Set<String> solvedIds; // 한 번이라도 푼 문제 id (모의수능 '안 푼 문제 우선'용)

  const UserStats({
    required this.totalSolved,
    required this.totalCorrect,
    required this.streakDays,
    required this.weeklySolved,
    required this.wrongProblems,
    required this.solvedByChapter,
    required this.continueFrom,
    required this.recent,
    this.attendance = const {},
    this.solvedIds = const {},
  });

  /// 첫 실행/초기화 상태 (전부 0).
  factory UserStats.empty() => const UserStats(
        totalSolved: 0,
        totalCorrect: 0,
        streakDays: 0,
        weeklySolved: 0,
        wrongProblems: {},
        solvedByChapter: {},
        continueFrom: null,
        recent: [],
        attendance: {},
        solvedIds: {},
      );

  double get accuracy => totalSolved == 0 ? 0 : totalCorrect / totalSolved;

  /// 특정 단원에서 고유하게 푼 문제 수.
  int solvedInChapter(String subject, String chapter) =>
      solvedByChapter['$subject|$chapter'] ?? 0;

  /// 특정 과목에서 고유하게 푼 문제 수(모든 단원 합).
  int solvedInSubject(String subject) {
    var n = 0;
    final prefix = '$subject|';
    solvedByChapter.forEach((k, v) {
      if (k.startsWith(prefix)) n += v;
    });
    return n;
  }

  UserStats copyWith({
    int? totalSolved,
    int? totalCorrect,
    int? streakDays,
    int? weeklySolved,
    Map<String, MathProblem>? wrongProblems,
    Map<String, int>? solvedByChapter,
    ContinueInfo? continueFrom,
    List<RecentRecord>? recent,
    Set<String>? attendance,
    Set<String>? solvedIds,
  }) {
    return UserStats(
      totalSolved: totalSolved ?? this.totalSolved,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      streakDays: streakDays ?? this.streakDays,
      weeklySolved: weeklySolved ?? this.weeklySolved,
      wrongProblems: wrongProblems ?? this.wrongProblems,
      solvedByChapter: solvedByChapter ?? this.solvedByChapter,
      continueFrom: continueFrom ?? this.continueFrom,
      recent: recent ?? this.recent,
      attendance: attendance ?? this.attendance,
      solvedIds: solvedIds ?? this.solvedIds,
    );
  }

  /// 로컬과 클라우드 상태를 합친다(기기 간 동기화).
  /// 누적값은 큰 쪽, 집합/맵은 합집합(진행률은 과목별 최댓값)으로 보수적 병합.
  UserStats mergedWith(UserStats other) {
    final wrong = {...other.wrongProblems, ...wrongProblems};
    final prog = <String, int>{...other.solvedByChapter};
    solvedByChapter.forEach((k, v) {
      prog[k] = v > (prog[k] ?? 0) ? v : (prog[k] ?? 0);
    });
    final attend = {...attendance, ...other.attendance};
    final solved = {...solvedIds, ...other.solvedIds};
    // 최근 기록: 둘을 합쳐 problemId 중복 제거(현재 것 우선), 20개까지
    final seen = <String>{};
    final mergedRecent = <RecentRecord>[];
    for (final r in [...recent, ...other.recent]) {
      if (seen.add('${r.problemId}|${r.dateLabel}')) mergedRecent.add(r);
      if (mergedRecent.length >= 20) break;
    }
    return UserStats(
      totalSolved: totalSolved > other.totalSolved ? totalSolved : other.totalSolved,
      totalCorrect:
          totalCorrect > other.totalCorrect ? totalCorrect : other.totalCorrect,
      streakDays: streakDays > other.streakDays ? streakDays : other.streakDays,
      weeklySolved:
          weeklySolved > other.weeklySolved ? weeklySolved : other.weeklySolved,
      wrongProblems: wrong,
      solvedByChapter: prog,
      continueFrom: continueFrom ?? other.continueFrom,
      recent: mergedRecent,
      attendance: attend,
      solvedIds: solved,
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> j) {
    final wrong = <String, MathProblem>{};
    (j['wrongProblems'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      wrong[k] = MathProblem.fromJson(v as Map<String, dynamic>);
    });
    final prog = <String, int>{};
    (j['solvedByChapter'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      prog[k] = (v as num).toInt();
    });
    return UserStats(
      totalSolved: j['totalSolved'] as int? ?? 0,
      totalCorrect: j['totalCorrect'] as int? ?? 0,
      streakDays: j['streakDays'] as int? ?? 0,
      weeklySolved: j['weeklySolved'] as int? ?? 0,
      wrongProblems: wrong,
      solvedByChapter: prog,
      continueFrom: j['continueFrom'] == null
          ? null
          : ContinueInfo.fromJson(j['continueFrom'] as Map<String, dynamic>),
      recent: (j['recent'] as List<dynamic>? ?? [])
          .map((e) => RecentRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      attendance:
          (j['attendance'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
      solvedIds:
          (j['solvedIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalSolved': totalSolved,
        'totalCorrect': totalCorrect,
        'streakDays': streakDays,
        'weeklySolved': weeklySolved,
        'wrongProblems': {
          for (final e in wrongProblems.entries) e.key: e.value.toJson()
        },
        'solvedByChapter': solvedByChapter,
        'continueFrom': continueFrom?.toJson(),
        'recent': recent.map((r) => r.toJson()).toList(),
        'attendance': attendance.toList(),
        'solvedIds': solvedIds.toList(),
      };
}
