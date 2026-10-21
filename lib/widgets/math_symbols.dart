import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 직접 그린 수학 기호. 폰트 글리프가 아니라 두툼한 둥근 선으로 그려서 크기·색에 상관없이
/// 또렷하고 귀엽다.
enum MathGlyph {
  plus,
  minus,
  times,
  divide,
  equals,
  pi,
  sqrt,
  sigma,
  infinity,
  percent,
}

/// 스티커처럼 잉크 테두리가 있는 컬러 기호. 결과 화면·빈 화면 장식에 쓴다.
class MathSymbolSticker extends StatelessWidget {
  final MathGlyph glyph;
  final Color color;
  final double size;
  final double angle; // 라디안

  const MathSymbolSticker(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 40,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: CustomPaint(
        size: Size.square(size),
        painter: MathSymbolPainter(glyph, color: color, outline: AppColors.ink),
      ),
    );
  }
}

/// [outline]이 null이면 테두리 없이 단색(배경 낙서용), 있으면 스티커 스타일.
class MathSymbolPainter extends CustomPainter {
  final MathGlyph glyph;
  final Color color;
  final Color? outline;

  MathSymbolPainter(this.glyph, {required this.color, this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final (strokes, dots) = _shape(glyph);
    const w = 12.0;

    void draw(Color c, double width, {bool fillDots = true}) {
      final p = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final s in strokes) {
        canvas.drawPath(s, p);
      }
      final f = Paint()..color = c;
      for (final d in dots) {
        canvas.drawCircle(d, width / 2, f);
      }
    }

    if (outline != null) draw(outline!, w + 7);
    draw(color, w);
    if (outline != null) {
      // 하이라이트: 가는 흰 선을 얹어 통통한 느낌
      final hl = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      for (final s in strokes) {
        canvas.drawPath(s.shift(const Offset(-2, -2.5)), hl);
      }
    }
  }

  static (List<Path>, List<Offset>) _shape(MathGlyph g) {
    Path line(double x1, double y1, double x2, double y2) => Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
    switch (g) {
      case MathGlyph.plus:
        return ([line(50, 20, 50, 80), line(20, 50, 80, 50)], const []);
      case MathGlyph.minus:
        return ([line(20, 50, 80, 50)], const []);
      case MathGlyph.times:
        return ([line(27, 27, 73, 73), line(73, 27, 27, 73)], const []);
      case MathGlyph.divide:
        return ([line(20, 50, 80, 50)], const [Offset(50, 25), Offset(50, 75)]);
      case MathGlyph.equals:
        return ([line(22, 37, 78, 37), line(22, 63, 78, 63)], const []);
      case MathGlyph.pi:
        final legL = Path()
          ..moveTo(37, 32)
          ..lineTo(36, 66)
          ..quadraticBezierTo(36, 78, 28, 78);
        final legR = Path()
          ..moveTo(64, 32)
          ..lineTo(64, 66)
          ..quadraticBezierTo(64, 78, 74, 76);
        return ([line(18, 32, 84, 32), legL, legR], const []);
      case MathGlyph.sqrt:
        final p = Path()
          ..moveTo(14, 56)
          ..lineTo(28, 50)
          ..lineTo(44, 80)
          ..lineTo(62, 22)
          ..lineTo(88, 22);
        return ([p], const []);
      case MathGlyph.sigma:
        final p = Path()
          ..moveTo(76, 24)
          ..lineTo(28, 24)
          ..lineTo(54, 50)
          ..lineTo(28, 76)
          ..lineTo(78, 76);
        return ([p], const []);
      case MathGlyph.infinity:
        final p = Path()
          ..moveTo(50, 50)
          ..cubicTo(60, 30, 86, 30, 86, 50)
          ..cubicTo(86, 70, 60, 70, 50, 50)
          ..cubicTo(40, 30, 14, 30, 14, 50)
          ..cubicTo(14, 70, 40, 70, 50, 50);
        return ([p], const []);
      case MathGlyph.percent:
        final ring = Path()
          ..addOval(Rect.fromCircle(center: const Offset(30, 30), radius: 10))
          ..addOval(Rect.fromCircle(center: const Offset(70, 70), radius: 10));
        return ([ring, line(76, 22, 24, 78)], const []);
    }
  }

  @override
  bool shouldRepaint(covariant MathSymbolPainter old) =>
      old.glyph != glyph || old.color != color || old.outline != outline;
}

/// 마스코트 주위에 기호 스티커를 흩뿌리는 장식(결과/빈 화면용).
class SymbolConfetti extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  const SymbolConfetti({
    super.key,
    required this.child,
    this.width = 260,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 14,
            child: MathSymbolSticker(
              MathGlyph.plus,
              color: AppColors.accent,
              size: 34,
              angle: -0.25,
            ),
          ),
          Positioned(
            left: 36,
            bottom: 8,
            child: MathSymbolSticker(
              MathGlyph.pi,
              color: AppColors.sunny,
              size: 36,
              angle: 0.2,
            ),
          ),
          Positioned(
            right: 6,
            top: 8,
            child: MathSymbolSticker(
              MathGlyph.sqrt,
              color: AppColors.pink,
              size: 38,
              angle: 0.18,
            ),
          ),
          Positioned(
            right: 30,
            bottom: 12,
            child: MathSymbolSticker(
              MathGlyph.times,
              color: AppColors.primary,
              size: 30,
              angle: -0.15,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 히어로 카드 등의 배경용 단색 기호 낙서.
class SymbolDoodlePainter extends CustomPainter {
  final Color color;
  SymbolDoodlePainter(this.color);

  static const _items = <(double, double, MathGlyph, double, double)>[
    (0.08, 0.14, MathGlyph.plus, 30, -0.2),
    (0.34, 0.80, MathGlyph.minus, 30, 0.1),
    (0.56, 0.10, MathGlyph.times, 28, 0.25),
    (0.66, 0.60, MathGlyph.pi, 36, -0.15),
    (0.88, 0.16, MathGlyph.divide, 30, 0.2),
    (0.18, 0.54, MathGlyph.sqrt, 34, 0.1),
    (0.90, 0.74, MathGlyph.sigma, 32, -0.1),
    (0.46, 0.46, MathGlyph.infinity, 30, 0.2),
    (0.08, 0.88, MathGlyph.equals, 26, -0.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, g, s, rot) in _items) {
      canvas.save();
      canvas.translate(size.width * fx, size.height * fy);
      canvas.rotate(rot);
      canvas.translate(-s / 2, -s / 2);
      MathSymbolPainter(g, color: color).paint(canvas, Size.square(s));
      canvas.restore();
    }
    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.36), 3.5, dot);
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.30), 3, dot);
    _star(canvas, Offset(size.width * 0.60, size.height * 0.90), 9, dot);
    _star(canvas, Offset(size.width * 0.94, size.height * 0.46), 7, dot);
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
  bool shouldRepaint(covariant SymbolDoodlePainter old) => old.color != color;
}
