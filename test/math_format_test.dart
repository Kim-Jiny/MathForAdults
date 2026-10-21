import 'dart:convert';
import 'dart:io';

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_for_adults/widgets/math_format.dart';

/// 변환 결과에서 수식 구간의 tex만 모아 돌려준다.
List<String> texOf(String s, {bool whole = false}) => [
      for (final g in splitMath(s, wholeIfMath: whole))
        if (g.isMath) g.tex!,
    ];

String joined(String s) =>
    splitMath(s).map((g) => g.isMath ? '⟦${g.tex}⟧' : g.text).join();

void main() {
  group('splitMath 변환', () {
    test('분수·극한·제곱', () {
      final t = texOf('lim(n→∞) (3n² + 1)/(n² + n) 의 값은?').single;
      expect(t, contains(r'\lim_{n\to \infty}'));
      expect(t, contains(r'\frac{3n^{2}+1}{n^{2}+n}'));
    });

    test('루트·시그마·적분', () {
      expect(texOf('lim(n→∞) (√(n² + 4n) − n)').single, contains(r'\sqrt{n^{2}+4n}'));
      expect(texOf('급수 ∑(n=1 to ∞) (1/3)ⁿ').single, contains(r'\sum_{n=1}^{\infty}'));
      expect(texOf('정적분 ∫₀¹ x·√(1−x) dx').single, contains(r'\int_{0}^{1}'));
    });

    test('벡터', () {
      expect(texOf('3PA⃗ + 2PB⃗ = 0⃗').single, contains(r'\overrightarrow{PA}'));
      expect(texOf('a⃗ = (3, −1)').single, contains(r'\vec{a}'));
    });

    test('분수 범위: 분자에 붙은 곱·절댓값, 쉼표는 제외', () {
      expect(texOf('Sₙ = n(a₁ + aₙ)/2').single, contains(r'\frac{n(a_{1}+a_{n})}{2}'));
      expect(texOf('d = |2x+5|/√(4+9)').single, contains(r'\frac{|2x+5|}{\sqrt{4+9}}'));
      expect(texOf('P(X=1)=3/10, P(X=2)=4/10').single, contains(r'\frac{3}{10}'));
      expect(texOf('1/log x').single, contains(r'\frac{1}{\log \ x}'));
    });

    test('분수 지수·첨자 분수', () {
      expect(texOf('3²⁄³').single, contains(r'^{\frac{2}{3}}'));
      expect(texOf('8^(2/3)').single, contains(r'^{\frac{2}{3}}'));
      expect(texOf('¹⁄₉').single, contains(r'\frac{1}{9}'));
    });

    test('한글·숫자만 있는 문장은 그대로', () {
      const s = '첫째항이 3이고 공차가 2인 등차수열의 제5항은?';
      expect(splitMath(s).every((g) => !g.isMath), isTrue);
      expect(joined('160, 162, 164 를 더한다'), '160, 162, 164 를 더한다');
    });

    test('한글 사이의 가운뎃점과 짝 없는 첨자는 수식으로 만들지 않는다', () {
      expect(joined('분자·분모를 나눈다'), '분자·분모를 나눈다');
      expect(joined('(빗변)² 을 구한다'), '(빗변)² 을 구한다');
    });

    test('wholeIfMath: 보기 전체가 숫자여도 수식 글꼴', () {
      expect(texOf('16', whole: true), ['16']);
      expect(texOf('16'), isEmpty);
      expect(texOf('3은 소수다', whole: true), isEmpty);
    });
  });

  test('코퍼스 전체: 모든 변환 결과가 flutter_math 파싱을 통과한다', () {
    final files = Directory('assets/problems')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !f.path.endsWith('index.json'));
    var segs = 0;
    final bad = <String>[];
    void check(String t) {
      for (final g in splitMath(t)) {
        if (!g.isMath) continue;
        segs++;
        if (Math.tex(g.tex!).parseError != null && bad.length < 20) {
          bad.add('${g.text}  ⇒  ${g.tex}');
        }
      }
    }

    for (final f in files) {
      for (final p in jsonDecode(f.readAsStringSync()) as List) {
        check(p['question'] as String);
        for (final c in (p['choices'] as List)) {
          check(c as String);
        }
        check(p['explanation'] as String);
        if (p['detailedExplanation'] != null) check(p['detailedExplanation'] as String);
        for (final h in ((p['hints'] ?? []) as List)) {
          check(h as String);
        }
      }
    }
    final concepts = jsonDecode(File('assets/concepts.json').readAsStringSync()) as Map;
    void walk(Object? o) {
      if (o is String) {
        check(o);
      } else if (o is List) {
        o.forEach(walk);
      } else if (o is Map) {
        o.values.forEach(walk);
      }
    }
    concepts.values.forEach(walk);
    expect(segs, greaterThan(100000));
    expect(bad, isEmpty, reason: bad.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
