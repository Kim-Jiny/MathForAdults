/// 과목 → 단원(chapter) 트리. 실제 수능 교육과정 단원명을 그대로 유지한다.
/// 세부 단원(lesson)은 문제 데이터의 lesson 필드에서 동적으로 모은다.
class Subject {
  final String name;
  final String emoji;
  final List<String> chapters;

  const Subject({
    required this.name,
    required this.emoji,
    required this.chapters,
  });
}

const List<Subject> kCurriculum = [
  Subject(
    name: '중학 수학',
    emoji: '🌱',
    chapters: ['수와 연산', '문자와 식', '방정식과 부등식', '함수', '도형', '확률과 통계'],
  ),
  Subject(
    name: '고등 공통수학',
    emoji: '📘',
    chapters: ['다항식', '방정식과 부등식', '도형의 방정식', '집합과 명제', '함수', '경우의 수'],
  ),
  Subject(
    name: '수학Ⅰ',
    emoji: '📐',
    chapters: ['지수함수와 로그함수', '삼각함수', '수열'],
  ),
  Subject(
    name: '수학Ⅱ',
    emoji: '📈',
    chapters: ['함수의 극한과 연속', '미분', '적분'],
  ),
  Subject(
    name: '확률과 통계',
    emoji: '🎲',
    chapters: ['경우의 수', '확률', '통계'],
  ),
  Subject(
    name: '미적분',
    emoji: '♾️',
    chapters: ['수열의 극한', '미분법', '적분법'],
  ),
  Subject(
    name: '기하',
    emoji: '📏',
    chapters: ['이차곡선', '평면벡터', '공간도형과 공간좌표'],
  ),
];
