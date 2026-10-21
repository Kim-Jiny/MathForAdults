import 'package:flutter/material.dart';

import '../theme/app_theme.dart' show kDisplayFont;
import 'app_card.dart';
import 'math_text.dart';

/// 시험(모의수능/주간시험) 응시 화면 공용 부품.

/// AppBar 아래 둥근 진행바.
PreferredSizeWidget examProgressBar(ThemeData theme, double value) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(18),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 10,
          backgroundColor: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );
}

/// 문제 카드: 번호 배지 + 우측 라벨 + 문제 본문.
class ExamQuestionCard extends StatelessWidget {
  final int index; // 0-based
  final int total;
  final String label;
  final String question;

  const ExamQuestionCard({
    super.key,
    required this.index,
    required this.total,
    required this.label,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: kDisplayFont,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ $total',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MathText(
            question,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 보기 타일(응시용): 선택 상태만 표시한다. 정답/오답은 제출 전까지 드러내지 않는다.
class ExamChoiceTile extends StatelessWidget {
  final int number; // 1-based
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const ExamChoiceTile({
    super.key,
    required this.number,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final border = selected ? scheme.primary : scheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: border, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: selected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: MathText(
                      text,
                      style: theme.textTheme.titleMedium,
                      wholeIfMath: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 문항 번호 네비게이터: 답한 문항은 채워진 동그라미, 현재 문항은 굵은 테두리.
class ExamNavigator extends StatelessWidget {
  final int count;
  final int current;
  final bool Function(int) answered;
  final ValueChanged<int> onTap;

  const ExamNavigator({
    super.key,
    required this.count,
    required this.current,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final done = answered(i);
          final isCurrent = i == current;
          return GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? scheme.primary : scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent || done
                      ? scheme.primary
                      : scheme.outlineVariant,
                  width: isCurrent ? 3 : 2,
                ),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: done ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
