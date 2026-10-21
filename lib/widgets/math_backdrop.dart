import 'package:flutter/material.dart';

import 'math_symbols.dart';

/// 은은한 수학 낙서 배경: 두툼한 둥근 선으로 그린 연산 기호·별·점.
/// Stack 안에서 콘텐츠 뒤에 깔아 쓴다. 풀이 흐름을 방해하지 않도록 매우 약하게.
class MathBackdrop extends StatelessWidget {
  final Color color;
  final double opacity;

  const MathBackdrop({super.key, required this.color, this.opacity = 0.10});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: SymbolDoodlePainter(color.withValues(alpha: opacity)),
        ),
      ),
    );
  }
}
