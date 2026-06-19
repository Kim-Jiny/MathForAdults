import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 난이도 단계 (쉬움 → 어려움). 성인이 부담 없이 단계를 올린다.
enum Difficulty {
  conceptCheck, // 개념 확인
  basic, // 기본 유형
  typical, // 대표 유형
  applied, // 응용 유형
  csatBasic, // 수능 기초
  csatReal, // 수능 실전
}

extension DifficultyInfo on Difficulty {
  String get label => switch (this) {
        Difficulty.conceptCheck => '개념 확인',
        Difficulty.basic => '기본 유형',
        Difficulty.typical => '대표 유형',
        Difficulty.applied => '응용 유형',
        Difficulty.csatBasic => '수능 기초',
        Difficulty.csatReal => '수능 실전',
      };

  Color get color => AppColors.difficultyColors[index];

  /// 모의수능 배점: 쉬움 2점 / 중간 3점 / 어려움 4점
  int get examPoints => switch (this) {
        Difficulty.conceptCheck || Difficulty.basic => 2,
        Difficulty.typical || Difficulty.applied => 3,
        Difficulty.csatBasic || Difficulty.csatReal => 4,
      };

  static Difficulty fromLabel(String label) => Difficulty.values.firstWhere(
        (d) => d.label == label,
        orElse: () => Difficulty.conceptCheck,
      );
}

/// 표시/진행 순서
const List<Difficulty> kDifficultyOrder = Difficulty.values;
