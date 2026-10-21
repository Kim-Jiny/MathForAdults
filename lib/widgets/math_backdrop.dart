import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 은은한 수학 낙서 배경: 흩뿌려진 연산 기호·별·동그라미.
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
          painter: _DoodlePainter(color: color.withValues(alpha: opacity)),
        ),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final Color color;
  _DoodlePainter({required this.color});

  // (x비율, y비율, 글리프, 크기, 회전)
  static const _glyphs = <(double, double, String, double, double)>[
    (0.06, 0.12, '+', 30, -0.2),
    (0.30, 0.78, '−', 34, 0.1),
    (0.50, 0.10, '×', 28, 0.25),
    (0.64, 0.58, 'π', 34, -0.15),
    (0.84, 0.16, '÷', 30, 0.2),
    (0.18, 0.52, '√', 28, 0.1),
    (0.90, 0.72, '∑', 30, -0.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, g, fs, rot) in _glyphs) {
      final tp = TextPainter(
        text: TextSpan(
          text: g,
          style: TextStyle(
            color: color,
            fontSize: fs,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // 동그라미 + 별 장식
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.40), 7, ring);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.88), 5, ring);
    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.86), 4, dot);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.34), 3, dot);
    _star(canvas, Offset(size.width * 0.58, size.height * 0.88), 9, dot);
    _star(canvas, Offset(size.width * 0.94, size.height * 0.42), 7, dot);
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.38;
      final p = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => old.color != color;
}
