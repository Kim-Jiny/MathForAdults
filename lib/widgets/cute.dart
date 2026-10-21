import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 파스텔 톤 파생색 모음 — [base]색을 라이트/다크 배경에 맞게 연하게 만든다.
class Pastel {
  final Color bg;
  final Color border;
  final Color fg;
  const Pastel(this.bg, this.border, this.fg);

  factory Pastel.of(BuildContext context, Color base) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pastel(
      base.withValues(alpha: dark ? 0.20 : 0.14),
      base.withValues(alpha: dark ? 0.50 : 0.42),
      dark
          ? Color.lerp(base, Colors.white, 0.35)!
          : Color.lerp(base, AppColors.ink, 0.25)!,
    );
  }
}

/// 동그란 이모지 배지. 목록/타일의 아이콘 자리에 쓴다.
class EmojiBadge extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;

  const EmojiBadge(
    this.emoji, {
    super.key,
    required this.color,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pastel.of(context, color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.bg,
        shape: BoxShape.circle,
        border: Border.all(color: p.border, width: 2),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.46, height: 1)),
    );
  }
}

/// 파스텔 색 카드(바로가기 타일). 이모지 + 제목 + 보조 문구.
class PastelTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? badge; // 우상단 작은 배지(예: 개수)

  const PastelTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.color,
    this.subtitle,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Pastel.of(context, color);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(24);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: p.border, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Color.alphaBlend(p.bg, theme.colorScheme.surface),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: p.border, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 34, height: 1.1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: p.fg,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (badge != null)
                    Positioned(right: 0, top: 0, child: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 말풍선. 왼쪽에 꼬리가 있어 옆의 마스코트가 말하는 것처럼 보인다.
class SpeechBubble extends StatelessWidget {
  final Widget child;
  const SpeechBubble({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _BubblePainter(
        fill: scheme.surface,
        border: scheme.outlineVariant,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 16, 12),
        child: child,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color fill;
  final Color border;
  _BubblePainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    const tail = 9.0;
    final body = RRect.fromLTRBR(
      tail,
      0,
      size.width,
      size.height,
      const Radius.circular(20),
    );
    final path = Path()..addRRect(body);
    final cy = size.height * 0.5;
    path
      ..moveTo(tail + 1, cy - 8)
      ..lineTo(0, cy)
      ..lineTo(tail + 1, cy + 8)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = border);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    // 꼬리와 몸통 사이 경계선 지우기
    canvas.drawRect(
      Rect.fromLTWH(tail - 1, cy - 7, 3.5, 14),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.fill != fill || old.border != border;
}

/// 원형 진행 링 안에 [child]를 넣는다(과목 카드의 이모지 등).
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final Color color;
  final Widget child;

  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.child,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0), color, track),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final Color track;
  _RingPainter(this.v, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 6.0;
    final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    if (v > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}

/// 숫자 + 라벨을 파스텔 말풍선 칩처럼 보여주는 통계 칸.
class StatBubble extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;

  const StatBubble({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Pastel.of(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.bg, theme.colorScheme.surface),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22, height: 1.1)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleLarge?.copyWith(color: p.fg),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
