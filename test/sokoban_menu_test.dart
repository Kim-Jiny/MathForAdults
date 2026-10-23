import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_for_adults/screens/game/sokoban_screen.dart';
import 'package:math_for_adults/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('선택 화면에 타일이 그려지고 1단계로 진입한다', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SokobanMenuScreen()),
      ),
    );
    await t.pump();
    await t.tap(find.text('1'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(SokobanPlayScreen), findsOneWidget);
  });

  testWidgets('아무것도 못 깼으면 1단계만 열려 있다', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SokobanMenuScreen()),
      ),
    );
    await t.pump();
    // 1단계는 숫자, 2~7단계는 🔒
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });
}
