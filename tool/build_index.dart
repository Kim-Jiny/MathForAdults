// assets/problems/<과목>.json 들을 읽어 index.json 을 재생성한다.
// 문제를 JSON에 추가/수정한 뒤 실행: dart run tool/build_index.dart
//
// 순수 Dart (flutter 미사용) — dart:io, dart:convert 만 쓴다.
import 'dart:convert';
import 'dart:io';

/// 커리큘럼 순서/이모지/단원 순서 (lib/models/curriculum.dart 와 일치 유지).
const _curriculum = [
  ('중학 수학', '🌱', 'middle.json', [
    '수와 연산', '문자와 식', '방정식과 부등식', '함수', '도형', '확률과 통계'
  ]),
  ('고등 공통수학', '📘', 'common.json', [
    '다항식', '방정식과 부등식', '도형의 방정식', '집합과 명제', '함수', '경우의 수'
  ]),
  ('수학Ⅰ', '📐', 'math1.json', ['지수함수와 로그함수', '삼각함수', '수열']),
  ('수학Ⅱ', '📈', 'math2.json', ['함수의 극한과 연속', '미분', '적분']),
  ('확률과 통계', '🎲', 'prob_stat.json', ['경우의 수', '확률', '통계']),
  ('미적분', '♾️', 'calculus.json', ['수열의 극한', '미분법', '적분법']),
  ('기하', '📏', 'geometry.json', ['이차곡선', '평면벡터', '공간도형과 공간좌표']),
];

const _difficultyOrder = [
  '개념 확인', '기본 유형', '대표 유형', '응용 유형', '수능 기초', '수능 실전'
];

void main() {
  const baseDir = 'assets/problems';

  // 모든 과목 문제 수집 (subject 필드 기준)
  final bySubject = <String, List<Map<String, dynamic>>>{};
  for (final entry in _curriculum) {
    final file = File('$baseDir/${entry.$3}');
    if (!file.existsSync()) continue;
    final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    for (final raw in list) {
      final p = raw as Map<String, dynamic>;
      bySubject.putIfAbsent(p['subject'] as String, () => []).add(p);
    }
  }

  final subjects = <Map<String, dynamic>>[];
  var totalProblems = 0;

  for (final (name, emoji, file, chapterOrder) in _curriculum) {
    final problems = bySubject[name] ?? const [];
    if (problems.isEmpty) continue;

    final chapters = <Map<String, dynamic>>[];
    for (final chapter in chapterOrder) {
      final chProblems =
          problems.where((p) => p['chapter'] == chapter).toList();
      if (chProblems.isEmpty) continue;

      // 세부 단원: 출현 순서 유지
      final lessonOrder = <String>[];
      for (final p in chProblems) {
        final l = p['lesson'] as String;
        if (!lessonOrder.contains(l)) lessonOrder.add(l);
      }

      final lessons = lessonOrder.map((lesson) {
        final lp = chProblems.where((p) => p['lesson'] == lesson).toList();
        final present = lp.map((p) => p['difficulty'] as String).toSet();
        final diffs =
            _difficultyOrder.where(present.contains).toList();
        return {'name': lesson, 'difficulties': diffs, 'count': lp.length};
      }).toList();

      chapters.add(
          {'name': chapter, 'count': chProblems.length, 'lessons': lessons});
    }
    if (chapters.isEmpty) continue;

    totalProblems += problems.length;
    subjects.add({
      'name': name,
      'emoji': emoji,
      'file': file,
      'chapters': chapters,
    });
  }

  const encoder = JsonEncoder.withIndent('  ');
  File('$baseDir/index.json').writeAsStringSync(
      encoder.convert({'subjects': subjects}));

  stdout.writeln(
      '✓ index.json 생성: ${subjects.length}과목, 총 $totalProblems문제');
}
