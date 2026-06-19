import 'difficulty.dart';

/// 문제 본문 없이 메타데이터만 담는 인덱스 (assets/problems/index.json).
/// 탐색 화면(과목/단원/세부단원/난이도/문제수)을 본문 로드 없이 구동한다.
class CurriculumIndex {
  final List<IdxSubject> subjects;
  const CurriculumIndex(this.subjects);

  IdxSubject? subject(String name) {
    for (final s in subjects) {
      if (s.name == name) return s;
    }
    return null;
  }

  IdxChapter? chapter(String subjectName, String chapterName) =>
      subject(subjectName)?.chapter(chapterName);

  factory CurriculumIndex.fromJson(Map<String, dynamic> json) => CurriculumIndex(
        (json['subjects'] as List<dynamic>)
            .map((s) => IdxSubject.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class IdxSubject {
  final String name;
  final String emoji;
  final String file; // 과목 문제 JSON 파일명
  final List<IdxChapter> chapters;

  const IdxSubject({
    required this.name,
    required this.emoji,
    required this.file,
    required this.chapters,
  });

  IdxChapter? chapter(String name) {
    for (final c in chapters) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// 이 과목에 존재하는 난이도 집합
  Set<Difficulty> get difficulties =>
      {for (final c in chapters) ...c.difficulties};

  factory IdxSubject.fromJson(Map<String, dynamic> json) => IdxSubject(
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '📚',
        file: json['file'] as String,
        chapters: (json['chapters'] as List<dynamic>)
            .map((c) => IdxChapter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class IdxChapter {
  final String name;
  final int count;
  final List<IdxLesson> lessons;

  const IdxChapter({
    required this.name,
    required this.count,
    required this.lessons,
  });

  Set<Difficulty> get difficulties =>
      {for (final l in lessons) ...l.difficulties};

  factory IdxChapter.fromJson(Map<String, dynamic> json) => IdxChapter(
        name: json['name'] as String,
        count: json['count'] as int? ?? 0,
        lessons: (json['lessons'] as List<dynamic>)
            .map((l) => IdxLesson.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}

class IdxLesson {
  final String name;
  final List<Difficulty> difficulties;
  final int count;

  const IdxLesson({
    required this.name,
    required this.difficulties,
    required this.count,
  });

  factory IdxLesson.fromJson(Map<String, dynamic> json) => IdxLesson(
        name: json['name'] as String,
        difficulties: (json['difficulties'] as List<dynamic>)
            .map((d) => DifficultyInfo.fromLabel(d as String))
            .toList(),
        count: json['count'] as int? ?? 0,
      );
}
