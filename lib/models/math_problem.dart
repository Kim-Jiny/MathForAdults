import 'difficulty.dart';

/// 문제 유형: 객관식(4지선다) / 단답형
enum ProblemType { choice, short }

/// 한 문제. 서버 연동 시 fromJson/toJson 으로 그대로 확장 가능한 평탄 구조.
class MathProblem {
  final String id;
  final String subject; // 예: 수학Ⅰ
  final String chapter; // 예: 수열
  final String lesson; // 예: 등차수열
  final Difficulty difficulty;
  final ProblemType type;
  final String question;

  // 객관식용
  final List<String> choices; // 4지선다 (short면 빈 리스트)
  final int answerIndex;

  // 단답형용
  final String? answerText; // 정답 문자열 (short)

  final String explanation; // 짧은 해설
  final String? detailedExplanation; // 상세 해설(접기)
  final String estimatedTime; // 예: "1분"

  const MathProblem({
    required this.id,
    required this.subject,
    required this.chapter,
    required this.lesson,
    required this.difficulty,
    this.type = ProblemType.choice,
    required this.question,
    this.choices = const [],
    this.answerIndex = 0,
    this.answerText,
    required this.explanation,
    this.detailedExplanation,
    required this.estimatedTime,
  });

  /// 위치 표시용 브레드크럼: "수학Ⅰ > 수열 > 등차수열"
  String get breadcrumb => '$subject > $chapter > $lesson';

  /// 화면에 보여줄 정답 텍스트
  String get correctAnswerDisplay => type == ProblemType.short
      ? (answerText ?? '')
      : (answerIndex >= 0 && answerIndex < choices.length
          ? choices[answerIndex]
          : '');

  /// 응답이 정답인지 판정.
  /// - choice: 선택한 보기 인덱스 문자열("0"~"3")
  /// - short: 입력한 문자열
  bool isCorrect(String response) {
    if (type == ProblemType.short) {
      return _normalize(response) == _normalize(answerText ?? '');
    }
    return int.tryParse(response.trim()) == answerIndex;
  }

  static String _normalize(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  factory MathProblem.fromJson(Map<String, dynamic> json) => MathProblem(
        id: json['id'] as String,
        subject: json['subject'] as String,
        chapter: json['chapter'] as String,
        lesson: json['lesson'] as String,
        difficulty: DifficultyInfo.fromLabel(json['difficulty'] as String),
        type: (json['type'] as String?) == 'short'
            ? ProblemType.short
            : ProblemType.choice,
        question: json['question'] as String,
        choices: (json['choices'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        answerIndex: json['answerIndex'] as int? ?? 0,
        answerText: json['answer'] as String?,
        explanation: json['explanation'] as String,
        detailedExplanation: json['detailedExplanation'] as String?,
        estimatedTime: json['estimatedTime'] as String? ?? '1분',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'chapter': chapter,
        'lesson': lesson,
        'difficulty': difficulty.label,
        'type': type == ProblemType.short ? 'short' : 'choice',
        'question': question,
        'choices': choices,
        'answerIndex': answerIndex,
        if (answerText != null) 'answer': answerText,
        'explanation': explanation,
        'detailedExplanation': detailedExplanation,
        'estimatedTime': estimatedTime,
      };
}
