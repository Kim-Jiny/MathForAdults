import 'package:flutter/material.dart';

import '../models/difficulty.dart';

/// 난이도를 색 점 + 라벨 형태의 작은 배지로 표시.
class DifficultyBadge extends StatelessWidget {
  final Difficulty difficulty;
  final bool compact;

  const DifficultyBadge(this.difficulty, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            difficulty.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
