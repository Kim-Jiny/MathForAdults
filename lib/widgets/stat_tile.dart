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
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor ?? theme.colorScheme.onSurface,
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
