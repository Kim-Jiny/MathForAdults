/// 세부 단원(소단원)별 핵심 개념 카드. 문제 풀기 전 공식·정의를 빠르게 훑는 용도.
/// points 항목은 LaTeX/유니코드 수식을 포함할 수 있다(MathText로 렌더).
class ConceptCard {
  final String subject;
  final String chapter;
  final String lesson;
  final String title;
  final List<String> points;

  const ConceptCard({
    required this.subject,
    required this.chapter,
    required this.lesson,
    required this.title,
    required this.points,
  });

  /// 조회 키: "과목|단원|세부단원"
  static String keyOf(String subject, String chapter, String lesson) =>
      '$subject|$chapter|$lesson';

  String get key => keyOf(subject, chapter, lesson);

  factory ConceptCard.fromJson(String key, Map<String, dynamic> j) {
    final parts = key.split('|');
    return ConceptCard(
      subject: parts.isNotEmpty ? parts[0] : '',
      chapter: parts.length > 1 ? parts[1] : '',
      lesson: parts.length > 2 ? parts[2] : '',
      title: j['title'] as String? ?? '',
      points: (j['points'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
