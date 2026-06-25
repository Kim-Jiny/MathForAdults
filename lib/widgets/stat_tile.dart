import 'package:flutter/material.dart';

/// 큰 숫자 + 작은 라벨. 통계/기록 카드에 사용.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: valueColor ?? theme.colorScheme.primary),
          const SizedBox(height: 4),
        ],
        // 값이 긴 텍스트(예: 과목명)여도 한 줄을 유지하도록 너비에 맞춰 축소.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
