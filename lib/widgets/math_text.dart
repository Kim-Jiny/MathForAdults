import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// 텍스트와 인라인 LaTeX(`$...$`)가 섞인 문자열을 렌더링한다.
/// 일반 텍스트는 단어 단위로 자연스럽게 줄바꿈되고, 수식은 가운데 정렬로 삽입된다.
class MathText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  const MathText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
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
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\$([^$]*)\$');
    var last = 0;

    for (final m in regex.allMatches(data)) {
      if (m.start > last) {
        spans.add(TextSpan(text: data.substring(last, m.start)));
      }
      final expr = m.group(1) ?? '';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            expr,
            textStyle: base,
            mathStyle: MathStyle.text,
            onErrorFallback: (err) => Text(
              expr,
              style: base.copyWith(color: Colors.red),
            ),
          ),
        ),
      );
      last = m.end;
    }
    if (last < data.length) {
      spans.add(TextSpan(text: data.substring(last)));
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(style: base, children: spans),
    );
  }
}
