import 'package:flutter/material.dart';

/// 앱 전역 색상 토큰. 차분한 블루 + 민트 포인트.
/// 정답/오답은 직관적이되 과하지 않은 채도.
class AppColors {
  AppColors._();

  // 포인트 컬러
  static const Color primary = Color(0xFF3A6FB0); // 차분한 블루
  static const Color primaryDark = Color(0xFF7AA9DC);
  static const Color accent = Color(0xFF2FB6A3); // 민트

  // 상태 컬러 (라이트)
  static const Color correct = Color(0xFF2E9E6B); // 부드러운 초록
  static const Color correctBg = Color(0xFFE7F5EE);
  static const Color wrong = Color(0xFFD66A5F); // 부드러운 빨강
  static const Color wrongBg = Color(0xFFFBECEA);

  // 상태 컬러 (다크) — 어두운 표면 위에서 가독성을 갖도록 밝은 변형 + 어두운 틴트 배경
  static const Color correctDark = Color(0xFF5FD2A0);
  static const Color correctBgDark = Color(0xFF17271F);
  static const Color wrongDark = Color(0xFFEF978B);
  static const Color wrongBgDark = Color(0xFF2B1B19);

  // 출석/연속 학습 강조색
  static const Color streak = Color(0xFFE08A3C);
  static const Color streakDark = Color(0xFFE6A862);

  /// 밝기에 따라 상태색을 골라준다. 라이트=채도색, 다크=밝은 변형.
  static Color correctOf(Brightness b) =>
      b == Brightness.dark ? correctDark : correct;
  static Color correctBgOf(Brightness b) =>
      b == Brightness.dark ? correctBgDark : correctBg;
  static Color wrongOf(Brightness b) =>
      b == Brightness.dark ? wrongDark : wrong;
  static Color wrongBgOf(Brightness b) =>
      b == Brightness.dark ? wrongBgDark : wrongBg;
  static Color streakOf(Brightness b) =>
      b == Brightness.dark ? streakDark : streak;

  // 배경/표면 (라이트)
  static const Color bgLight = Color(0xFFF6F8FB); // 아주 연한 블루그레이
  static const Color surfaceLight = Colors.white;
  static const Color outlineLight = Color(0xFFE6EAF0);

  // 배경/표면 (다크)
  static const Color bgDark = Color(0xFF121519);
  static const Color surfaceDark = Color(0xFF1C2026);
  static const Color outlineDark = Color(0xFF2C323B);

  // 난이도 단계별 색 (은은한 단계감)
  static const List<Color> difficultyColors = [
    Color(0xFF6FB1E0), // 개념 확인
    Color(0xFF4F95D6), // 기본 유형
    Color(0xFF3A6FB0), // 대표 유형
    Color(0xFF8E6FC4), // 응용 유형
    Color(0xFFD89A4E), // 수능 기초
    Color(0xFFD66A5F), // 수능 실전
  ];
}
