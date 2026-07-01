/// 세부 단원(소단원)별 핵심 개념 카드.
///
/// 두 가지 용도로 쓰인다.
///  - 요약: [points] 중 앞부분만 빠르게 보여주는 카드/시트 (문제 풀기 전 훑기)
///  - 상세: [formulas]·[conditions]·[examples]·[mistakes]·[quiz] 까지 갖춘
///    확장형 개념 페이지(ConceptDetailScreen)
///
/// 상세 필드는 모두 선택값이라, 요약(title/points)만 있는 기존 concepts.json도
/// 그대로 동작한다(없는 섹션은 화면에서 숨김).
/// 모든 텍스트는 LaTeX/유니코드 수식을 포함할 수 있다(MathText로 렌더).
class ConceptCard {
  final String subject;
  final String chapter;
  final String lesson;
  final String title;

  /// 핵심 포인트(요약). 요약 화면은 앞 [summaryCount]개만 보여준다.
  final List<String> points;

  /// 한 줄 개념 설명(선택).
  final String? intro;

  /// 공식 모음.
  final List<String> formulas;

  /// 성립 조건·적용 범위·주의점.
  final List<String> conditions;

  /// 예시(질문 → 풀이).
  final List<ConceptExample> examples;

  /// 자주 하는 실수.
  final List<String> mistakes;

  /// 미니 O/X 퀴즈.
  final List<ConceptQuiz> quiz;

  const ConceptCard({
    required this.subject,
    required this.chapter,
    required this.lesson,
    required this.title,
    required this.points,
    this.intro,
    this.formulas = const [],
    this.conditions = const [],
    this.examples = const [],
    this.mistakes = const [],
    this.quiz = const [],
  });

  /// 요약 화면에 노출할 최대 포인트 수.
  static const int summaryCount = 3;

  /// 요약에서 우선 보여줄 포인트(앞 [summaryCount]개).
  List<String> get summaryPoints => points.take(summaryCount).toList();

  /// 상세 페이지로 넘길 가치가 있는 추가 콘텐츠가 있는지.
  bool get hasDetail =>
      points.length > summaryCount ||
      (intro != null && intro!.isNotEmpty) ||
      formulas.isNotEmpty ||
      conditions.isNotEmpty ||
      examples.isNotEmpty ||
      mistakes.isNotEmpty ||
      quiz.isNotEmpty;

  /// 조회 키: "과목|단원|세부단원"
  static String keyOf(String subject, String chapter, String lesson) =>
      '$subject|$chapter|$lesson';

  String get key => keyOf(subject, chapter, lesson);

  factory ConceptCard.fromJson(String key, Map<String, dynamic> j) {
    final parts = key.split('|');
    List<String> strList(String field) =>
        (j[field] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
    return ConceptCard(
      subject: parts.isNotEmpty ? parts[0] : '',
      chapter: parts.length > 1 ? parts[1] : '',
      lesson: parts.length > 2 ? parts[2] : '',
      title: j['title'] as String? ?? '',
      points: strList('points'),
      intro: (j['intro'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['intro'] as String).trim(),
      formulas: strList('formulas'),
      conditions: strList('conditions'),
      examples: (j['examples'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConceptExample.fromJson)
          .toList(),
      mistakes: strList('mistakes'),
      quiz: (j['quiz'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConceptQuiz.fromJson)
          .toList(),
    );
  }
}

/// 개념 예시 한 개: 질문과 풀이.
class ConceptExample {
  final String prompt;
  final String solution;

  const ConceptExample({required this.prompt, required this.solution});

  factory ConceptExample.fromJson(Map<String, dynamic> j) => ConceptExample(
    prompt: j['prompt'] as String? ?? '',
    solution: j['solution'] as String? ?? '',
  );
}

/// 미니 O/X 퀴즈 한 문항.
class ConceptQuiz {
  final String statement;
  final bool answer; // true = O(맞다), false = X(틀리다)
  final String? explanation;

  const ConceptQuiz({
    required this.statement,
    required this.answer,
    this.explanation,
  });

  factory ConceptQuiz.fromJson(Map<String, dynamic> j) => ConceptQuiz(
    statement: j['statement'] as String? ?? '',
    answer: j['answer'] as bool? ?? false,
    explanation: (j['explanation'] as String?)?.trim().isEmpty ?? true
        ? null
        : (j['explanation'] as String).trim(),
  );
}
