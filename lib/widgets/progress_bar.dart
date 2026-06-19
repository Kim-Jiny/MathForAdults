import 'package:flutter/material.dart';

/// 둥근 진행률 바 + (옵션) 우측 퍼센트 텍스트.
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final bool showPercent;
  final Color? color;
  final double height;

  const ProgressBar({
    super.key,
    required this.value,
    this.showPercent = true,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: height,
              backgroundColor: scheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ),
        if (showPercent) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
