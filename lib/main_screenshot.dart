// 앱스토어 스크린샷 촬영 전용 진입점 (배포 빌드에는 쓰이지 않음).
//   flutter build ios --simulator --debug -t lib/main_screenshot.dart --dart-define=SHOT=home
//   (--dart-define=SHOT=home 등으로 화면 지정)
// SHOT: home | subjects | quiz | concept | stats | exam
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/content_repository.dart';
import 'l10n/app_localizations.dart';
import 'models/concept_card.dart';
import 'models/difficulty.dart';
import 'models/math_problem.dart';
import 'models/user_stats.dart';
import 'screens/concept/concept_detail_screen.dart';
import 'screens/exam/mock_exam_screen.dart';
import 'screens/main_shell.dart';
import 'screens/quiz/quiz_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/math_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const shot = String.fromEnvironment('SHOT', defaultValue: 'home');
  final repo = ContentRepository();
  final s1 = await repo.loadSubject('수학Ⅰ');
  final s2 = await repo.loadSubject('수학Ⅱ');
  final concepts = await repo.loadConcepts();

  final now = DateTime.now();
  String key(DateTime d) => StatsNotifier.dateKey(d);
  final today = key(now);
  final wrong = s1.where((p) => p.type == ProblemType.choice).take(6).toList();

  RecentRecord rec(MathProblem p, bool ok, DateTime d) => RecentRecord(
    problemId: p.id,
    subject: p.subject,
    lesson: p.lesson,
    correct: ok,
    dateLabel: '',
    dateKey: key(d),
  );
  final stats = UserStats(
    totalSolved: 184,
    totalCorrect: 141,
    streakDays: 12,
    weeklySolved: 23,
    weeklyKey: key(now.subtract(Duration(days: now.weekday - 1))),
    wrongProblems: {for (final p in wrong) p.id: p},
    wrongAddedAt: {for (final p in wrong) p.id: now.millisecondsSinceEpoch},
    solvedByChapter: const {
      '중학 수학|수와 연산': 58,
      '중학 수학|문자와 식': 41,
      '중학 수학|방정식과 부등식': 33,
      '고등 공통수학|다항식': 36,
      '고등 공통수학|방정식과 부등식': 22,
      '수학Ⅰ|지수함수와 로그함수': 64,
      '수학Ⅰ|삼각함수': 31,
      '수학Ⅰ|수열': 47,
      '수학Ⅱ|미분': 28,
      '수학Ⅱ|함수의 극한과 연속': 19,
      '확률과 통계|확률': 14,
      '미적분|수열의 극한': 9,
    },
    continueFrom: const ContinueInfo(
      subject: '수학Ⅰ',
      chapter: '수열',
      lesson: '등차수열',
      progress: 0.4,
    ),
    recent: [
      rec(s1[0], true, now),
      rec(s1[1], true, now),
      rec(s1[2], false, now),
      rec(s2[0], true, now.subtract(const Duration(days: 1))),
      rec(s2[1], true, now.subtract(const Duration(days: 1))),
      rec(s1[3], false, now.subtract(const Duration(days: 2))),
    ],
    attendance: {
      for (var i = 0; i < 12; i++) key(now.subtract(Duration(days: i))),
    },
    solvedIds: {for (final p in s1.take(80)) p.id},
    weeklyTestHistory: [
      WeeklyTestRecord(
        weekKey: key(now.subtract(const Duration(days: 21))),
        correct: 3,
        total: 6,
        dateKey: today,
      ),
      WeeklyTestRecord(
        weekKey: key(now.subtract(const Duration(days: 14))),
        correct: 4,
        total: 6,
        dateKey: today,
      ),
      WeeklyTestRecord(
        weekKey: key(now.subtract(const Duration(days: 7))),
        correct: 5,
        total: 6,
        dateKey: today,
      ),
    ],
    weeklyTestStreak: 3,
  );
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_stats_v1', jsonEncode(stats.toJson()));
  await prefs.setString('settings_v1', jsonEncode(const Settings().toJson()));
  await prefs.setBool('mfa_ads_removed', true);

  // 개념: 공식·예시·실수·O/X가 모두 있는 카드 중 첫 번째
  ConceptCard? card;
  for (final c in concepts.values) {
    if (c.subject == '수학Ⅰ' &&
        c.formulas.isNotEmpty &&
        c.examples.isNotEmpty &&
        c.mistakes.isNotEmpty &&
        c.quiz.isNotEmpty &&
        c.points.length >= 3) {
      card = c;
      break;
    }
  }
  // 문제: 힌트·해설이 있고 질문이 비교적 짧은 객관식
  bool latex(MathProblem p) =>
      p.question.contains(r'$') && p.choices.every((c) => c.length < 24);
  final quizP = s1.firstWhere(
    (p) =>
        p.type == ProblemType.choice &&
        p.hints.isNotEmpty &&
        latex(p) &&
        p.question.length < 80 &&
        p.difficulty == Difficulty.typical,
    orElse: () => s1.firstWhere(latex, orElse: () => s1.first),
  );
  final examPs = [
    ...s1.where((p) => p.type == ProblemType.choice && latex(p)).take(5),
    ...s2.where((p) => p.type == ProblemType.choice && latex(p)).take(3),
  ];

  final Widget home = switch (shot) {
    'subjects' => const MainShell(initialIndex: 1),
    'stats' => const MainShell(initialIndex: 3),
    'quiz' => QuizScreen(
      problems: [quizP],
      sessionTitle: quizP.lesson,
      initialSelected: quizP.answerIndex,
    ),
    'gallery' => _Gallery(
      items: const [
        'lim(n→∞) (3n² + 1)/(n² + n) 의 값은?',
        '무한등비급수 1/3 + (1/3)² + (1/3)³ + ⋯ 의 합은?',
        '급수 ∑(n=1 to ∞) (1/3)ⁿ 의 합을 구하여라.',
        '정적분 ∫₀¹ x·√(1−x) dx 의 값은?',
        '벡터 a⃗ = (3, −1)일 때, 3PA⃗ + 2PB⃗ = 0⃗ 이면?',
        '합: Sₙ = n(a₁ + aₙ)/2 = n{2a₁ + (n−1)d}/2',
        '직선까지의 거리 d = |2(2)−3(3)+5|/√(4+9) = 0/√13',
        '8^(2/3) 와 e^(x²−2x), 2³ × 2²',
        'f(x) = eᶜᵒˢˣ 이고 f′(x) = 5(3x + 1)⁴ × 3',
        '순환소수 1.2̄3̄ = 1.232323⋯ 이고 140°, ½, 6½',
        '₈C₆ = ₈C₂ = 28, A ∩ B = ∅, A ⊂ B, x ≥ 1, α ≠ β',
        'lim[h→0] {sin(π/3 + h) − sin(π/3)} / h',
        '확률 P(Aᶜ ∩ B) = P(Aᶜ) × P(B), E(X²) = 46/10',
        '학생 A, B, C, D, E 5명의 키(cm)가 160, 162, 164',
      ],
    ),
    'concept' => ConceptDetailScreen(card: card!),
    'exam' => MockExamScreen(
      problems: examPs,
      duration: const Duration(minutes: 100),
      title: '모의수능 · 실전',
    ),
    _ => const MainShell(),
  };

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
}

/// 수식 변환 점검용 갤러리(스토어 스크린샷과 무관, 개발 확인용).
class _Gallery extends StatelessWidget {
  final List<String> items;
  const _Gallery({required this.items});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in items) ...[
            Text(t, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            MathText(t, style: const TextStyle(fontSize: 17)),
            const Divider(),
          ],
        ],
      ),
    ),
  );
}
