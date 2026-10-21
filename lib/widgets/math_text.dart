import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'math_format.dart';

/// 텍스트와 수식이 섞인 문자열을 렌더링한다.
///
/// - 문자열에 `$...$`가 있으면 그 구간을 LaTeX로 그린다(직접 쓴 수식 우선).
/// - 없으면 유니코드/ASCII로 적힌 수식(`2³ × 2²`, `lim(n→∞) 1/n`, `√(x+1)` …)을
///   자동으로 찾아 LaTeX로 조판한다([splitMath]). 변환이 불확실하거나 렌더링에 실패하면
///   원문 그대로 보여준다.
/// 일반 텍스트는 단어 단위로 자연스럽게 줄바꿈된다.
class MathText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  /// 문자열 전체가 수식 문자로만 이뤄졌다면 숫자만 있어도 수식 글꼴로 그린다
  /// (보기 `2`, `16`, `1/2`가 나란히 있을 때 글꼴을 맞추려고 보기·정답 표시에 쓴다).
  final bool wholeIfMath;

  const MathText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.wholeIfMath = false,
  });

  @override
  Widget build(BuildContext context) {
    // 문제·해설은 가독성을 위해 항상 본문(시스템) 폰트로 — 제목용 둥근 폰트가 들어와도 걸러낸다.
    final raw = style ?? DefaultTextStyle.of(context).style;
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: raw.fontSize,
      fontWeight: raw.fontWeight,
      fontStyle: raw.fontStyle,
      color: raw.color,
      height: 1.5,
    );

    final segs = data.contains(r'$')
        ? _explicitSegs(data)
        : splitMath(data, wholeIfMath: wholeIfMath);

    final spans = <InlineSpan>[];
    for (final g in segs) {
      if (!g.isMath) {
        spans.add(TextSpan(text: g.text));
        continue;
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            g.tex!,
            textStyle: base,
            mathStyle: MathStyle.text,
            // 렌더링 실패 시 원문을 그대로(빨간 글씨 없이) 보여준다.
            onErrorFallback: (err) => Text(g.text, style: base),
          ),
        ),
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(style: base, children: spans),
    );
  }

  /// `$...$`로 직접 적힌 수식 구간 분리.
  static List<MathSeg> _explicitSegs(String data) {
    final out = <MathSeg>[];
    var last = 0;
    for (final m in RegExp(r'\$([^$]*)\$').allMatches(data)) {
      if (m.start > last) out.add(MathSeg(data.substring(last, m.start)));
      final expr = m.group(1) ?? '';
      out.add(MathSeg(expr, expr));
      last = m.end;
    }
    if (last < data.length) out.add(MathSeg(data.substring(last)));
    return out;
  }
}
