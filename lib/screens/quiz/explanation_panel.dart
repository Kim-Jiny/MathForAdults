import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import '../../widgets/math_text.dart';

/// 정답/해설 패널. 정답 여부 → 짧은 해설 → 상세 해설(접기) → 액션들.
class ExplanationPanel extends ConsumerStatefulWidget {
  final MathProblem problem;
  final bool correct;
  final VoidCallback onSimilar;

  const ExplanationPanel({
    super.key,
    required this.problem,
    required this.correct,
    required this.onSimilar,
  });

  @override
  ConsumerState<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends ConsumerState<ExplanationPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.problem;
    final correct = widget.correct;
    final color = correct ? const Color(0xFF2E9E6B) : const Color(0xFFD66A5F);
    final bg = correct ? const Color(0xFFE7F5EE) : const Color(0xFFFBECEA);
    final inReview = ref.watch(statsProvider).wrongProblems.containsKey(p.id);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 정답 여부 (부드러운 칭찬 / 부담 없는 문구)
          Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.lightbulb_outline_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                correct ? '정답이에요, 좋아요!' : '괜찮아요, 같이 볼까요',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 정답 표시
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('정답  ',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if (p.type == ProblemType.choice) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xFF2E9E6B), shape: BoxShape.circle),
                  child: Text('${p.answerIndex + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: MathText(p.correctAnswerDisplay)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: color.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          // 짧은 해설
          MathText(p.explanation,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
          // 상세 해설 (접기/펼치기)
          if (p.detailedExplanation != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text('자세한 풀이',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        )),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MathText(p.detailedExplanation!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
          const SizedBox(height: 14),
          // 액션
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () =>
                    ref.read(statsProvider.notifier).toggleReview(p),
                icon: Icon(
                  inReview ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(inReview ? '저장됨' : '다시 풀 문제에 저장'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: widget.onSimilar,
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('비슷한 문제 풀기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
