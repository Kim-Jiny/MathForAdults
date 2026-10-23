import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_for_adults/screens/settings/account_section.dart';

void main() {
  /// 확인창을 띄우고, 닫힐 때 받은 값을 [out]에 담는다.
  Future<void> open(WidgetTester t, [List<bool?>? out]) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await showDialog<bool>(
                context: context,
                builder: (_) => const DeleteAccountDialog(),
              );
              out?.add(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  FilledButton confirmButton(WidgetTester t) =>
      t.widget<FilledButton>(find.widgetWithText(FilledButton, '탈퇴하기'));

  testWidgets('입력 전에는 탈퇴 버튼이 꺼져 있다', (t) async {
    await open(t);
    expect(confirmButton(t).onPressed, isNull);
  });

  testWidgets('다른 글자를 쓰면 계속 꺼져 있다', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField), '탈퇴');
    await t.pump();
    expect(confirmButton(t).onPressed, isNull);
  });

  testWidgets('회원탈퇴를 정확히 쓰면 켜지고 true를 돌려준다', (t) async {
    final out = <bool?>[];
    await open(t, out);
    await t.enterText(find.byType(TextField), ' 회원탈퇴 ');
    await t.pump();
    expect(confirmButton(t).onPressed, isNotNull);
    await t.tap(find.text('탈퇴하기'));
    await t.pumpAndSettle();
    expect(out, [true]);
  });

  testWidgets('취소하면 false', (t) async {
    final out = <bool?>[];
    await open(t, out);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(out, [false]);
  });
}
