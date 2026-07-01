import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_for_adults/l10n/app_localizations.dart';
import 'package:math_for_adults/models/concept_card.dart';
import 'package:math_for_adults/models/difficulty.dart';
import 'package:math_for_adults/models/exam_analysis.dart';
import 'package:math_for_adults/models/math_problem.dart';
import 'package:math_for_adults/models/user_stats.dart';
import 'package:math_for_adults/state/app_state.dart';
import 'package:math_for_adults/screens/quiz/quiz_launcher.dart';
import 'package:math_for_adults/screens/settings/settings_screen.dart';

const _p = MathProblem(
  id: 'test_01',
  subject: '수학Ⅰ',
  chapter: '수열',
  lesson: '등차수열',
  difficulty: Difficulty.basic,
  question: 'q',
  choices: ['1', '2', '3', '4'],
  answerIndex: 2,
  explanation: 'e',
  estimatedTime: '1분',
);

void main() {
  group('StatsNotifier', () {
    test('오답이면 다시 풀 문제에 추가, 정답이면 제거', () {
      final n = StatsNotifier();
      n.recordAnswer(_p, correct: false);
      expect(n.state.wrongProblems.containsKey('test_01'), isTrue);

      n.recordAnswer(_p, correct: true);
      expect(n.state.wrongProblems.containsKey('test_01'), isFalse);
    });

    test('풀이 시 통계 누적', () {
      final n = StatsNotifier();
      final before = n.state.totalSolved;
      n.recordAnswer(_p, correct: true);
      expect(n.state.totalSolved, before + 1);
    });

    test('이번 주 풀이 수는 주가 바뀌면 리셋', () {
      final n = StatsNotifier();
      n.recordAnswer(_p, correct: true, answeredAt: DateTime(2026, 6, 22));
      n.recordAnswer(_p, correct: true, answeredAt: DateTime(2026, 6, 28));
      expect(n.state.weeklySolved, 2);

      n.recordAnswer(_p, correct: true, answeredAt: DateTime(2026, 6, 29));
      expect(n.state.weeklySolved, 1);
    });

    test('저장된 예전 주간 수치는 로드 시 현재 주 기준으로 정리', () async {
      SharedPreferences.setMockInitialValues({
        'user_stats_v1': jsonEncode({
          'totalSolved': 7,
          'totalCorrect': 5,
          'streakDays': 0,
          'weeklySolved': 7,
          'weeklyKey': '2000-01-03',
          'wrongProblems': {},
          'solvedByChapter': {},
          'recent': [],
          'attendance': [],
          'solvedIds': [],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final n = StatsNotifier(prefs);
      expect(n.state.totalSolved, 7);
      expect(n.state.weeklySolved, 0);
      expect(n.state.weeklyKey, isNot('2000-01-03'));
    });

    test('최근 기록은 날짜 키를 저장', () {
      final n = StatsNotifier();
      n.recordAnswer(_p, correct: true, answeredAt: DateTime(2026, 6, 30));
      expect(n.state.recent.single.dateLabel, '오늘');
      expect(n.state.recent.single.dateKey, '2026-06-30');
    });

    test('주간 수치 병합은 더 최신 주차를 사용', () {
      final older = UserStats.empty().copyWith(
        weeklySolved: 4,
        weeklyKey: '2026-06-22',
      );
      final newer = UserStats.empty().copyWith(
        weeklySolved: 1,
        weeklyKey: '2026-06-29',
      );
      final merged = older.mergedWith(newer);
      expect(merged.weeklyKey, '2026-06-29');
      expect(merged.weeklySolved, 1);
    });

    test('최근 기록 병합은 같은 문제라도 날짜가 다르면 유지', () {
      final first = UserStats.empty().copyWith(
        recent: const [
          RecentRecord(
            problemId: 'test_01',
            subject: '수학Ⅰ',
            lesson: '등차수열',
            correct: true,
            dateLabel: '오늘',
            dateKey: '2026-06-30',
          ),
        ],
      );
      final second = UserStats.empty().copyWith(
        recent: const [
          RecentRecord(
            problemId: 'test_01',
            subject: '수학Ⅰ',
            lesson: '등차수열',
            correct: false,
            dateLabel: '오늘',
            dateKey: '2026-07-01',
          ),
        ],
      );
      expect(first.mergedWith(second).recent.length, 2);
    });

    test('toggleReview 토글', () {
      final n = StatsNotifier();
      n.toggleReview(_p);
      expect(n.state.wrongProblems.containsKey('test_01'), isTrue);
      n.toggleReview(_p);
      expect(n.state.wrongProblems.containsKey('test_01'), isFalse);
    });

    test('출석 체크인 + 연속일수', () {
      final n = StatsNotifier();
      final today = DateTime(2026, 6, 19);
      n.checkIn(today.subtract(const Duration(days: 1))); // 어제
      n.checkIn(today); // 오늘 → 연속 2일
      expect(n.state.attendance.contains(StatsNotifier.dateKey(today)), isTrue);
      expect(n.state.streakDays, 2);
      // 같은 날 재출석은 무시
      n.checkIn(today);
      expect(n.state.attendance.length, 2);
    });
  });

  group('모의수능 결과 분석', () {
    MathProblem prob({
      required String subject,
      required String lesson,
      required Difficulty difficulty,
      required int answerIndex,
    }) => MathProblem(
      id: '$subject-$lesson-$answerIndex',
      subject: subject,
      chapter: '단원',
      lesson: lesson,
      difficulty: difficulty,
      question: 'q',
      choices: const ['a', 'b', 'c', 'd'],
      answerIndex: answerIndex,
      explanation: 'e',
      estimatedTime: '1분',
    );

    final problems = [
      prob(subject: '수학Ⅰ', lesson: '등차수열', difficulty: Difficulty.basic, answerIndex: 0), // 2점
      prob(subject: '수학Ⅱ', lesson: '미분', difficulty: Difficulty.typical, answerIndex: 1), // 3점
      prob(subject: '미적분', lesson: '급수', difficulty: Difficulty.csatReal, answerIndex: 2), // 4점
      prob(subject: '미적분', lesson: '급수', difficulty: Difficulty.applied, answerIndex: 3), // 3점
    ];
    // p1 정답, p2 오답, p3 정답, p4 미응답
    final answers = {0: '0', 1: '0', 2: '2'};
    final a = ExamAnalysis.from(problems, answers);

    test('점수·정답률 집계', () {
      expect(a.maxScore, 12);
      expect(a.score, 6); // 2 + 4
      expect(a.correctCount, 2);
      expect(a.totalCount, 4);
      expect(a.accuracy, 0.5);
    });

    test('배점별 통계', () {
      expect(a.tiers.map((t) => t.points), [2, 3, 4]);
      expect(a.tiers[0].correct, 1); // 2점 1/1
      expect(a.tiers[1].correct, 0); // 3점 0/2
      expect(a.tiers[2].correct, 1); // 4점 1/1
    });

    test('공통 vs 선택 영역', () {
      expect(a.common.total, 2);
      expect(a.common.scoreGot, 2);
      expect(a.common.scoreMax, 5);
      expect(a.elective.total, 2);
      expect(a.elective.scoreGot, 4);
      expect(a.elective.scoreMax, 7);
    });

    test('오답 단원·과목·다시풀기 목록', () {
      expect(a.wrongProblems.length, 2); // p2, p4
      expect(a.wrongBySubject['수학Ⅱ'], 1);
      expect(a.wrongBySubject['미적분'], 1);
      // 급수(미적분)는 1문항만 틀림(p4), 미분(수학Ⅱ)도 1문항.
      final lessons = a.wrongLessons.map((l) => l.lesson).toSet();
      expect(lessons, {'미분', '급수'});
    });
  });

  test('수능 점수대 매핑', () {
    expect(
      QuizLauncher.csatBands[2],
      containsAll([Difficulty.conceptCheck, Difficulty.basic]),
    );
    expect(
      QuizLauncher.csatBands[4],
      containsAll([Difficulty.csatBasic, Difficulty.csatReal]),
    );
  });

  testWidgets('앱 정보 다이얼로그가 레이아웃 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AboutAppDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 무한 너비 등 레이아웃 예외가 없어야 한다.
    expect(tester.takeException(), isNull);
    expect(find.text('닫기'), findsOneWidget);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);
  });

  group('JSON 에셋 무결성', () {
    final dir = Directory('assets/problems');
    final problemFiles = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'),
        )
        .toList();

    test('과목 파일 존재', () {
      expect(problemFiles, isNotEmpty);
    });

    test('문제 유형별 필수 필드 · id 유일', () {
      final ids = <String>{};
      for (final f in problemFiles) {
        final list = jsonDecode(f.readAsStringSync()) as List<dynamic>;
        for (final raw in list) {
          final p = MathProblem.fromJson(raw as Map<String, dynamic>);
          if (p.type == ProblemType.short) {
            expect(
              p.answerText?.trim() ?? '',
              isNotEmpty,
              reason: '${p.id} 단답 정답',
            );
          } else {
            expect(p.choices.length, 4, reason: '${p.id} 보기');
            expect(p.answerIndex, inInclusiveRange(0, 3), reason: '${p.id} 정답');
          }
          expect(p.question.trim(), isNotEmpty, reason: '${p.id} 문제');
          expect(p.explanation.trim(), isNotEmpty, reason: '${p.id} 해설');
          expect(ids.add(p.id), isTrue, reason: '${p.id} 중복');
        }
      }
    });

    test('단답형 채점 동작', () {
      const sp = MathProblem(
        id: 's',
        subject: '수학Ⅰ',
        chapter: '수열',
        lesson: '등차수열',
        difficulty: Difficulty.basic,
        type: ProblemType.short,
        question: 'q',
        answerText: '17',
        explanation: 'e',
        estimatedTime: '1분',
      );
      expect(sp.isCorrect(' 17 '), isTrue); // 공백 무시
      expect(sp.isCorrect('18'), isFalse);
    });

    test('index.json 의 파일 참조가 실제 존재', () {
      final index =
          jsonDecode(File('assets/problems/index.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final s in index['subjects'] as List<dynamic>) {
        final file = File('assets/problems/${(s as Map)['file']}');
        expect(file.existsSync(), isTrue, reason: '${s['file']} 없음');
      }
    });

    test('concepts.json 파싱 · 필수 필드 무결성', () {
      final json =
          jsonDecode(File('assets/concepts.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(json, isNotEmpty);
      json.forEach((key, value) {
        final raw = value as Map<String, dynamic>;
        final c = ConceptCard.fromJson(key, raw);
        expect(c.title.trim(), isNotEmpty, reason: '$key title');
        expect(c.points, isNotEmpty, reason: '$key points');
        // 파서가 원본 항목을 누락 없이 모두 읽었는지(개수 일치).
        expect(
          c.points.length,
          (raw['points'] as List?)?.length ?? 0,
          reason: '$key points 개수',
        );
        expect(
          c.examples.length,
          (raw['examples'] as List?)?.length ?? 0,
          reason: '$key examples 개수',
        );
        expect(
          c.quiz.length,
          (raw['quiz'] as List?)?.length ?? 0,
          reason: '$key quiz 개수',
        );
        // 예시는 질문이 있어야 의미가 있다.
        for (final e in c.examples) {
          expect(e.prompt.trim(), isNotEmpty, reason: '$key example prompt');
        }
        // O/X 퀴즈는 명제가 있어야 한다(answer는 모델에서 bool 보장).
        for (final q in c.quiz) {
          expect(q.statement.trim(), isNotEmpty, reason: '$key quiz statement');
        }
      });
    });

    test('concepts.json 키가 실제 커리큘럼 단원과 연결됨', () {
      // 개념 조회는 "과목|단원|세부단원"으로 하므로, 키가 index.json의
      // 실제 lesson과 정확히 일치하지 않으면 개념 카드가 표시되지 않는다.
      final index =
          jsonDecode(File('assets/problems/index.json').readAsStringSync())
              as Map<String, dynamic>;
      final valid = <String>{};
      for (final s in index['subjects'] as List<dynamic>) {
        final subject = (s as Map)['name'] as String;
        for (final ch in s['chapters'] as List<dynamic>) {
          final chapter = (ch as Map)['name'] as String;
          for (final le in ch['lessons'] as List<dynamic>) {
            valid.add('$subject|$chapter|${(le as Map)['name']}');
          }
        }
      }
      final concepts =
          jsonDecode(File('assets/concepts.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final key in concepts.keys) {
        expect(valid.contains(key), isTrue, reason: '연결 안되는 개념 키: $key');
      }
    });
  });
}
