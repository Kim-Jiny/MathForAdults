import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 마스코트 표정.
enum MascotMood { happy, cheer, think, sleepy }

/// 앱 마스코트 "새싹이" — 머리에 새싹이 난 동글동글한 친구.
/// 코드로 그려서 에셋이 필요 없고, 크기·표정·색을 자유롭게 바꿀 수 있다.
/// [bounce]를 켜면 위아래로 살짝 둥실거린다(홈 히어로 등 한 곳에만 쓰는 것을 권장).
class Mascot extends StatefulWidget {
  final double size;
  final MascotMood mood;
  final Color? bodyColor;
  final bool bounce;

  const Mascot({
    super.key,
    this.size = 96,
    this.mood = MascotMood.happy,
    this.bodyColor,
    this.bounce = false,
  });

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.bounce) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.bodyColor ?? const Color(0xFFB9AEFF);
    Widget paint(double t) => CustomPaint(
          size: Size.square(widget.size),
          painter: _MascotPainter(mood: widget.mood, body: body, t: t),
        );
    final c = _c;
    if (c == null) return paint(0);
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) => paint(c.value),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final MascotMood mood;
  final Color body;
  final double t; // 0..1 (bounce 진행도)

  _MascotPainter({required this.mood, required this.body, required this.t});

  static const _ink = AppColors.ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final bob = math.sin(t * 2 * math.pi) * 2.2;

    // 바닥 그림자 (둥실거릴 때 살짝 작아짐)
    final shadowW = 46 - bob * 1.2;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 94), width: shadowW, height: 7),
      Paint()..color = _ink.withValues(alpha: 0.10),
    );

    canvas.save();
    canvas.translate(0, bob);

    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color c) => Paint()..color = c;

    // 발
    for (final x in [36.0, 64.0]) {
      final r = Rect.fromCenter(center: Offset(x, 89), width: 17, height: 10);
      canvas.drawOval(r, fill(body));
      canvas.drawOval(r, outline);
    }

    // 팔 (cheer는 번쩍 든 만세)
    final up = mood == MascotMood.cheer;
    for (final side in [-1.0, 1.0]) {
      final cx = 50 + side * 39;
      final cy = up ? 44.0 : 62.0;
      final r = Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 17);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(side * (up ? -0.5 : 0.35));
      canvas.translate(-cx, -cy);
      canvas.drawOval(r, fill(body));
      canvas.drawOval(r, outline);
      canvas.restore();
    }

    // 몸통
    final bodyR = RRect.fromRectAndRadius(
      const Rect.fromLTRB(15, 24, 85, 91),
      const Radius.circular(32),
    );
    canvas.drawRRect(bodyR, fill(body));
    // 하이라이트
    canvas.drawArc(
      const Rect.fromLTRB(23, 31, 49, 55),
      math.pi * 1.05,
      math.pi * 0.55,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(bodyR, outline);

    // 새싹
    final stem = Path()
      ..moveTo(50, 25)
      ..quadraticBezierTo(50, 16, 52, 11);
    canvas.drawPath(stem, outline..strokeWidth = 3);
    const leaf = Color(0xFF55D68F);
    for (final side in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(52, 12)
        ..quadraticBezierTo(52 + side * 10, side < 0 ? 3.0 : 0.0,
            52 + side * 20, side < 0 ? 7.0 : 13.0)
        ..quadraticBezierTo(52 + side * 10, 19, 52, 12)
        ..close();
      canvas.drawPath(p, fill(leaf));
      canvas.drawPath(p, outline..strokeWidth = 2.6);
    }
    outline.strokeWidth = 3;

    // 볼터치
    for (final x in [28.0, 72.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 66), width: 12, height: 8),
        fill(AppColors.pink.withValues(alpha: 0.65)),
      );
    }

    // 눈
    final eyePaint = fill(_ink);
    final eyeStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (final x in [38.0, 62.0]) {
      switch (mood) {
        case MascotMood.sleepy:
          canvas.drawArc(
            Rect.fromCenter(center: Offset(x, 55), width: 12, height: 9),
            0.15,
            math.pi - 0.3,
            false,
            eyeStroke,
          );
        case MascotMood.cheer:
          canvas.drawArc(
            Rect.fromCenter(center: Offset(x, 57), width: 12, height: 10),
            math.pi + 0.15,
            math.pi - 0.3,
            false,
            eyeStroke,
          );
        case MascotMood.happy || MascotMood.think:
          final look = mood == MascotMood.think ? const Offset(1.5, -2) : Offset.zero;
          final r = Rect.fromCenter(
              center: Offset(x, 55) + look, width: 10, height: 13);
          canvas.drawOval(r, eyePaint);
          canvas.drawCircle(
              Offset(x + 2, 51.5) + look, 2.2, fill(Colors.white));
      }
    }

    // 입
    final mouthStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case MascotMood.happy:
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 64), width: 14, height: 10),
          0.2,
          math.pi - 0.4,
          false,
          mouthStroke,
        );
      case MascotMood.cheer:
        final m = Path()
          ..moveTo(42, 63)
          ..quadraticBezierTo(50, 63, 58, 63)
          ..quadraticBezierTo(57, 76, 50, 76)
          ..quadraticBezierTo(43, 76, 42, 63)
          ..close();
        canvas.drawPath(m, fill(_ink));
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(50, 73), width: 8, height: 5),
          fill(AppColors.pink),
        );
      case MascotMood.think:
        canvas.drawCircle(const Offset(52, 67), 3, mouthStroke..strokeWidth = 2.6);
      case MascotMood.sleepy:
        canvas.drawArc(
          Rect.fromCenter(center: const Offset(50, 66), width: 9, height: 6),
          0.2,
          math.pi - 0.4,
          false,
          mouthStroke..strokeWidth = 2.6,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MascotPainter old) =>
      old.mood != mood || old.body != body || old.t != t;
}
