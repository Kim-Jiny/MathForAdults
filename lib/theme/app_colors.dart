import 'package:flutter/material.dart';

/// 앱 전역 색상 토큰. 따뜻한 크림 배경 + 말랑한 바이올렛 포인트 + 파스텔 보조색.
/// 정답/오답은 직관적이되 과하지 않은 채도.
class AppColors {
  AppColors._();

  // 포인트 컬러
  static const Color primary = Color(0xFF7C6CF2); // 말랑한 바이올렛
  static const Color primaryDark = Color(0xFFB0A6FF);
  static const Color accent = Color(0xFF3CCFAE); // 민트
  static const Color pink = Color(0xFFFF8FB1); // 볼터치/장식
  static const Color sunny = Color(0xFFFFC94D); // 별/하이라이트

  // 텍스트 (잉크 느낌의 짙은 보라 네이비)
  static const Color ink = Color(0xFF2E2A45);
  static const Color inkSoft = Color(0xFF7A7391);
  static const Color inkDark = Color(0xFFF1EEFF);
  static const Color inkSoftDark = Color(0xFFA9A3C4);

  // 상태 컬러 (라이트)
  static const Color correct = Color(0xFF34B27F);
  static const Color correctBg = Color(0xFFE2F6EC);
  static const Color wrong = Color(0xFFEF6F7B);
  static const Color wrongBg = Color(0xFFFFE8EA);

  // 상태 컬러 (다크)
  static const Color correctDark = Color(0xFF63D9A6);
  static const Color correctBgDark = Color(0xFF1A2B25);
  static const Color wrongDark = Color(0xFFFF9AA3);
  static const Color wrongBgDark = Color(0xFF30202A);

  // 출석/연속 학습 강조색
  static const Color streak = Color(0xFFFF9A3D);
  static const Color streakDark = Color(0xFFFFB566);

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
  static Color inkOf(Brightness b) => b == Brightness.dark ? inkDark : ink;

  // 배경/표면 (라이트)
  static const Color bgLight = Color(0xFFFFF8EE); // 따뜻한 크림
  static const Color surfaceLight = Colors.white;
  static const Color outlineLight = Color(0xFFF0E3D0); // 말랑한 베이지 테두리

  // 배경/표면 (다크)
  static const Color bgDark = Color(0xFF17141F);
  static const Color surfaceDark = Color(0xFF221E2E);
  static const Color outlineDark = Color(0xFF38314A);

  // 난이도 단계별 색 (쉬움 → 어려움: 민트 → 하늘 → 바이올렛 → 오키드 → 오렌지 → 코랄)
  static const List<Color> difficultyColors = [
    Color(0xFF3FC5A2), // 개념 확인
    Color(0xFF4DA8E8), // 기본 유형
    Color(0xFF7C6CF2), // 대표 유형
    Color(0xFFC26BE0), // 응용 유형
    Color(0xFFFF9A3D), // 수능 기초
    Color(0xFFEF6F7B), // 수능 실전
  ];
}
