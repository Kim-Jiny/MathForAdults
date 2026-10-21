import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 제목·버튼 등 "캐릭터" 있는 글자에 쓰는 둥근 폰트. 본문/문제 텍스트는 시스템 폰트 유지.
const String kDisplayFont = 'Jua';

/// 라이트/다크 테마 정의. 크림 배경, 말랑한 테두리, 둥근 모서리, 또렷한 텍스트 계층.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          tertiary: AppColors.sunny,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkSoft,
          outlineVariant: AppColors.outlineLight,
          surfaceContainerHighest: const Color(0xFFF6EEE2),
          surfaceContainer: const Color(0xFFFBF3E7),
          primaryContainer: const Color(0xFFE9E5FF),
        );
    return _build(scheme, AppColors.bgLight);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primaryDark,
          onPrimary: const Color(0xFF241C5C),
          secondary: AppColors.accent,
          tertiary: AppColors.sunny,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.inkDark,
          onSurfaceVariant: AppColors.inkSoftDark,
          outlineVariant: AppColors.outlineDark,
          surfaceContainerHighest: const Color(0xFF2D2840),
          surfaceContainer: const Color(0xFF282338),
          primaryContainer: const Color(0xFF3A3470),
        );
    return _build(scheme, AppColors.bgDark);
  }

  static ThemeData _build(ColorScheme scheme, Color bg) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );
    final t = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    // 큰 제목류만 둥근 폰트. (body*/label*는 시스템 폰트 — 문제·해설 가독성 유지)
    TextStyle? d(TextStyle? s) => s?.copyWith(fontFamily: kDisplayFont);
    final textTheme = t.copyWith(
      displayLarge: d(t.displayLarge),
      displayMedium: d(t.displayMedium),
      displaySmall: d(t.displaySmall),
      headlineLarge: d(t.headlineLarge),
      headlineMedium: d(t.headlineMedium),
      headlineSmall: d(t.headlineSmall),
      titleLarge: d(t.titleLarge),
      titleMedium: d(t.titleMedium),
      titleSmall: d(t.titleSmall),
    );

    final radius16 = BorderRadius.circular(18);
    const buttonText = TextStyle(
      fontFamily: kDisplayFont,
      fontSize: 17,
      fontWeight: FontWeight.w400,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: scheme.outlineVariant, width: 2),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: buttonText.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant, width: 2),
        backgroundColor: scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: kDisplayFont,
            fontSize: 12,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1.5,
        space: 1,
      ),
    );
  }
}
