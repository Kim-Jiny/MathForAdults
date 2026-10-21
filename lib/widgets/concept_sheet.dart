import 'package:flutter/material.dart';

import '../models/concept_card.dart';
import '../screens/concept/concept_detail_screen.dart';
import 'mascot.dart';
import 'math_text.dart';

/// 개념 요약 바텀시트. 핵심 포인트 몇 개만 빠르게 훑고,
/// 더 보고 싶으면 "자세히 보기"로 확장형 개념 페이지로 이어진다.
void showConceptSheet(BuildContext context, ConceptCard card) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      final summary = card.summaryPoints;
      final hidden = card.points.length - summary.length;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Mascot(size: 52, mood: MascotMood.think),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title, style: theme.textTheme.titleLarge),
                          Text(
                            '${card.subject} › ${card.chapter}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: summary.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 10),
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: MathText(
                            summary[i],
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConceptDetailScreen(card: card),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(hidden > 0 ? '자세히 보기 (+$hidden개 더)' : '자세히 보기'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
