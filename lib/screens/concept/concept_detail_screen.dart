import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/concept_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/math_text.dart';
import '../quiz/quiz_launcher.dart';

/// 확장형 개념 페이지. 요약 카드의 "자세히 보기"에서 이어진다.
/// 공식·조건·예시·자주 하는 실수·미니 O/X 퀴즈를 보여주고,
/// 하단에서 이 개념의 문제로 바로 넘어간다.
class ConceptDetailScreen extends ConsumerWidget {
  final ConceptCard card;

  const ConceptDetailScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('개념 · ${card.title}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              '${card.subject} › ${card.chapter}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (card.intro != null) ...[
              const SizedBox(height: 12),
              MathText(
                card.intro!,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              ),
            ],

            _Section(
              icon: Icons.lightbulb_outline_rounded,
              title: '핵심 요약',
              show: card.points.isNotEmpty,
              child: _Bullets(items: card.points),
            ),
            _Section(
              icon: Icons.functions_rounded,
              title: '공식',
              show: card.formulas.isNotEmpty,
              child: _FormulaList(items: card.formulas),
            ),
            _Section(
              icon: Icons.rule_rounded,
              title: '조건 · 주의',
              show: card.conditions.isNotEmpty,
              child: _Bullets(items: card.conditions),
            ),
            _Section(
              icon: Icons.menu_book_rounded,
              title: '예시',
              show: card.examples.isNotEmpty,
              child: _ExampleList(items: card.examples),
            ),
            _Section(
              icon: Icons.warning_amber_rounded,
              title: '자주 하는 실수',
              show: card.mistakes.isNotEmpty,
              child: _Bullets(items: card.mistakes, color: AppColors.wrongOf(theme.brightness)),
            ),
            _Section(
              icon: Icons.quiz_outlined,
              title: '미니 O / X 퀴즈',
              show: card.quiz.isNotEmpty,
              child: _MiniQuiz(items: card.quiz),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton.icon(
          onPressed: () {
            QuizLauncher.startLesson(
              context,
              ref,
              subject: card.subject,
              chapter: card.chapter,
              lesson: card.lesson,
              title: card.title,
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('이 개념 문제 풀기'),
        ),
      ),
    );
  }
}

/// 아이콘 + 제목을 단 섹션 래퍼. [show]가 false면 아무것도 그리지 않는다.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool show;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.show,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 불릿 목록. [color]를 주면 불릿 점에 그 색을 쓴다(실수 섹션 등).
class _Bullets extends StatelessWidget {
  final List<String> items;
  final Color? color;

  const _Bullets({required this.items, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dot = color ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 10),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                Expanded(
                  child: MathText(
                    t,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 공식을 강조 배경의 칩 카드로 보여준다.
class _FormulaList extends StatelessWidget {
  final List<String> items;

  const _FormulaList({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final f in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: MathText(
              f,
              style: theme.textTheme.titleSmall?.copyWith(height: 1.5),
            ),
          ),
      ],
    );
  }
}

/// 예시: 질문(강조) → 풀이.
class _ExampleList extends StatelessWidget {
  final List<ConceptExample> items;

  const _ExampleList({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final e in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MathText(
                  e.prompt,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                if (e.solution.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  MathText(
                    e.solution,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 미니 O/X 퀴즈. 문항마다 O/X를 누르면 즉시 채점 + 해설을 보여준다.
class _MiniQuiz extends StatefulWidget {
  final List<ConceptQuiz> items;

  const _MiniQuiz({required this.items});

  @override
  State<_MiniQuiz> createState() => _MiniQuizState();
}

class _MiniQuizState extends State<_MiniQuiz> {
  /// 문항별 사용자의 선택(없으면 미응답). true=O, false=X
  late final List<bool?> _picked = List.filled(widget.items.length, null);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.items.length; i++)
          _QuizItem(
            quiz: widget.items[i],
            picked: _picked[i],
            onPick: (v) => setState(() => _picked[i] = v),
          ),
      ],
    );
  }
}

class _QuizItem extends StatelessWidget {
  final ConceptQuiz quiz;
  final bool? picked;
  final ValueChanged<bool> onPick;

  const _QuizItem({
    required this.quiz,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = picked != null;
    final isCorrect = answered && picked == quiz.answer;
    final correctColor = AppColors.correctOf(theme.brightness);
    final wrongColor = AppColors.wrongOf(theme.brightness);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: !answered
              ? scheme.outlineVariant
              : (isCorrect ? correctColor : wrongColor).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(
            quiz.statement,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OxButton(
                label: 'O',
                selected: picked == true,
                // 채점 후: 정답 버튼은 초록, 내가 고른 오답 버튼은 빨강.
                tint: !answered
                    ? null
                    : (quiz.answer == true
                          ? correctColor
                          : (picked == true ? wrongColor : null)),
                onTap: answered ? null : () => onPick(true),
              ),
              const SizedBox(width: 10),
              _OxButton(
                label: 'X',
                selected: picked == false,
                tint: !answered
                    ? null
                    : (quiz.answer == false
                          ? correctColor
                          : (picked == false ? wrongColor : null)),
                onTap: answered ? null : () => onPick(false),
              ),
            ],
          ),
          if (answered) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 18,
                  color: isCorrect ? correctColor : wrongColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect ? '정답이에요' : '아쉬워요, 정답은 ${quiz.answer ? "O" : "X"}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isCorrect ? correctColor : wrongColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (quiz.explanation != null) ...[
                        const SizedBox(height: 4),
                        MathText(
                          quiz.explanation!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OxButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? tint; // 채점 결과 강조색(null이면 중립)
  final VoidCallback? onTap;

  const _OxButton({
    required this.label,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = tint ?? scheme.primary;
    final active = selected || tint != null;
    return Expanded(
      child: Material(
        color: active ? base.withValues(alpha: 0.12) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? base : scheme.outlineVariant,
                width: active ? 1.6 : 1.2,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: active ? base : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
