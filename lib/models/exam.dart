/// 모의수능 프리셋. 공통(수Ⅰ+수Ⅱ)/선택 과목별 배점 구간 문항 수를 고정해
/// 만점이 일정하도록 구성한다. (배점: 2점=개념·기본, 3점=대표·응용, 4점=수능기초·실전)
enum ExamPreset { real, half, mini }

/// 배점 구간별 문항 수 (two=2점, three=3점, four=4점)
class TierSpec {
  final int two;
  final int three;
  final int four;
  const TierSpec(this.two, this.three, this.four);

  int get count => two + three + four;
  int get points => two * 2 + three * 3 + four * 4;
}

extension ExamPresetInfo on ExamPreset {
  String get label => switch (this) {
        ExamPreset.real => '실전 모의 (30문항 · 100분)',
        ExamPreset.half => '하프 모의 (15문항 · 50분)',
        ExamPreset.mini => '미니 모의 (10문항 · 25분)',
      };

  String get short => switch (this) {
        ExamPreset.real => '실전',
        ExamPreset.half => '하프',
        ExamPreset.mini => '미니',
      };

  Duration get duration => switch (this) {
        ExamPreset.real => const Duration(minutes: 100),
        ExamPreset.half => const Duration(minutes: 50),
        ExamPreset.mini => const Duration(minutes: 25),
      };

  /// 공통(수Ⅰ+수Ⅱ) 구간별 문항 수
  TierSpec get common => switch (this) {
        ExamPreset.real => const TierSpec(3, 11, 8), // 22문항, 71점
        ExamPreset.half => const TierSpec(2, 6, 3), // 11문항
        ExamPreset.mini => const TierSpec(2, 4, 1), // 7문항
      };

  /// 선택 1과목 구간별 문항 수
  TierSpec get elective => switch (this) {
        ExamPreset.real => const TierSpec(0, 3, 5), // 8문항, 29점 → 합 100점
        ExamPreset.half => const TierSpec(0, 2, 2), // 4문항
        ExamPreset.mini => const TierSpec(0, 2, 1), // 3문항
      };

  int get totalQuestions => common.count + elective.count;
  int get totalPoints => common.points + elective.points;
}

/// 선택 과목 후보
const List<String> kElectiveSubjects = ['확률과 통계', '미적분', '기하'];

/// 공통 과목 (수능 수학 공통)
const List<String> kCommonSubjects = ['수학Ⅰ', '수학Ⅱ'];
