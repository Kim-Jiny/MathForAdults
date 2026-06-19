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
  final Map<String, double> subjectProgress; // 과목명 → 0..1
  final ContinueInfo? continueFrom;
  final List<RecentRecord> recent;

  const UserStats({
    required this.totalSolved,
    required this.totalCorrect,
    required this.streakDays,
    required this.weeklySolved,
    required this.wrongProblems,
    required this.subjectProgress,
    required this.continueFrom,
    required this.recent,
  });

  /// 첫 실행/초기화 상태 (전부 0).
  factory UserStats.empty() => const UserStats(
        totalSolved: 0,
        totalCorrect: 0,
        streakDays: 0,
        weeklySolved: 0,
        wrongProblems: {},
        subjectProgress: {},
        continueFrom: null,
        recent: [],
      );

  double get accuracy => totalSolved == 0 ? 0 : totalCorrect / totalSolved;

  /// 가장 진행률이 낮은(=약한) 과목명 (기록 있는 과목 중)
  String? get weakestSubject {
    if (subjectProgress.isEmpty) return null;
    final entries = subjectProgress.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.first.key;
  }

  UserStats copyWith({
    int? totalSolved,
    int? totalCorrect,
    int? streakDays,
    int? weeklySolved,
    Map<String, MathProblem>? wrongProblems,
    Map<String, double>? subjectProgress,
    ContinueInfo? continueFrom,
    List<RecentRecord>? recent,
  }) {
    return UserStats(
      totalSolved: totalSolved ?? this.totalSolved,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      streakDays: streakDays ?? this.streakDays,
      weeklySolved: weeklySolved ?? this.weeklySolved,
      wrongProblems: wrongProblems ?? this.wrongProblems,
      subjectProgress: subjectProgress ?? this.subjectProgress,
      continueFrom: continueFrom ?? this.continueFrom,
      recent: recent ?? this.recent,
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> j) {
    final wrong = <String, MathProblem>{};
    (j['wrongProblems'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      wrong[k] = MathProblem.fromJson(v as Map<String, dynamic>);
    });
    final prog = <String, double>{};
    (j['subjectProgress'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      prog[k] = (v as num).toDouble();
    });
    return UserStats(
      totalSolved: j['totalSolved'] as int? ?? 0,
      totalCorrect: j['totalCorrect'] as int? ?? 0,
      streakDays: j['streakDays'] as int? ?? 0,
      weeklySolved: j['weeklySolved'] as int? ?? 0,
      wrongProblems: wrong,
      subjectProgress: prog,
      continueFrom: j['continueFrom'] == null
          ? null
          : ContinueInfo.fromJson(j['continueFrom'] as Map<String, dynamic>),
      recent: (j['recent'] as List<dynamic>? ?? [])
          .map((e) => RecentRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
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
        'subjectProgress': subjectProgress,
        'continueFrom': continueFrom?.toJson(),
        'recent': recent.map((r) => r.toJson()).toList(),
      };
}
