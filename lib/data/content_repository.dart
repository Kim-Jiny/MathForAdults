import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/curriculum_index.dart';
import '../models/difficulty.dart';
import '../models/math_problem.dart';

/// 문제 콘텐츠 로더. 인덱스는 1회 로드, 본문은 과목 단위로 lazy 로드 + 캐시.
/// 서버 연동 시 이 클래스의 로드 메서드만 원격 호출로 교체하면 된다.
class ContentRepository {
  static const _base = 'assets/problems';

  CurriculumIndex? _index;
  final Map<String, List<MathProblem>> _subjectCache = {};

  /// 메타데이터 인덱스 (시작 시 1회).
  Future<CurriculumIndex> loadIndex() async {
    if (_index != null) return _index!;
    final raw = await rootBundle.loadString('$_base/index.json');
    _index = CurriculumIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _index!;
  }

  /// 한 과목의 전체 문제 (캐시). 그 과목에 진입할 때만 호출.
  Future<List<MathProblem>> loadSubject(String subjectName) async {
    if (_subjectCache.containsKey(subjectName)) {
      return _subjectCache[subjectName]!;
    }
    final index = await loadIndex();
    final subject = index.subject(subjectName);
    if (subject == null) return const [];
    final raw = await rootBundle.loadString('$_base/${subject.file}');
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((p) => MathProblem.fromJson(p as Map<String, dynamic>))
        .toList();
    _subjectCache[subjectName] = list;
    return list;
  }

  /// 세부 단원(+난이도) 문제. 풀이 세션 시작용.
  Future<List<MathProblem>> loadLesson(
    String subject,
    String chapter,
    String lesson, {
    Difficulty? difficulty,
  }) async {
    final all = await loadSubject(subject);
    return all.where((p) {
      if (p.chapter != chapter || p.lesson != lesson) return false;
      if (difficulty != null && p.difficulty != difficulty) return false;
      return true;
    }).toList();
  }

  /// 난이도 묶음(수능 점수대)에 맞는 문제를 여러 과목에서 무작위로 모은다.
  /// 인덱스로 해당 난이도를 가진 과목만 골라 로드하므로 전체 로드를 피한다.
  Future<List<MathProblem>> randomByDifficulties(
    List<Difficulty> difficulties, {
    int count = 8,
  }) async {
    final index = await loadIndex();
    final wanted = difficulties.toSet();
    final candidateSubjects = index.subjects
        .where((s) => s.difficulties.any(wanted.contains))
        .map((s) => s.name)
        .toList()
      ..shuffle();

    final pool = <MathProblem>[];
    for (final name in candidateSubjects) {
      final problems = await loadSubject(name);
      pool.addAll(problems.where((p) => wanted.contains(p.difficulty)));
      if (pool.length >= count * 3) break; // 충분히 모이면 중단
    }
    pool.shuffle();
    return pool.take(count).toList();
  }

  /// 캐시에 이미 로드된 과목들에서 id로 조회 (복습 보조용).
  MathProblem? cachedById(String id) {
    for (final list in _subjectCache.values) {
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    return null;
  }
}
