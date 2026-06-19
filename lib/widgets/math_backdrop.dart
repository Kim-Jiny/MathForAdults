import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 은은한 수학 분위기 배경: 옅은 좌표 그리드 + 사인 곡선.
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
          painter: _MathBackdropPainter(
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}

class _MathBackdropPainter extends CustomPainter {
  final Color color;
  _MathBackdropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: color.a * 0.6)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 사인 곡선
    final curve = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final midY = size.height * 0.62;
    final amp = size.height * 0.16;
    for (double x = 0; x <= size.width; x += 4) {
      final y = midY - amp * math.sin(x / size.width * 4 * math.pi);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, curve);
  }

  @override
  bool shouldRepaint(covariant _MathBackdropPainter old) => old.color != color;
}
