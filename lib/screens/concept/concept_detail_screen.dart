import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/concept_card.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cute.dart';
import '../../widgets/mascot.dart';
import '../../widgets/math_text.dart';
import '../quiz/quiz_launcher.dart';

/// 확장형 개념 페이지. 요약 카드의 "자세히 보기"에서 이어진다.
/// 마스코트 인트로 → 색깔별 섹션 카드(핵심/공식/조건/예시/실수/O·X 퀴즈) 순서로 읽히고,
/// 하단에서 이 개념의 문제로 바로 넘어간다.
class ConceptDetailScreen extends ConsumerWidget {
  final ConceptCard card;

  const ConceptDetailScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wrong = AppColors.wrongOf(theme.brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('개념 노트')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // 제목 + 위치
            Text(
              card.title,
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.25),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _chip(context, card.subject, AppColors.primary),
                _chip(context, card.chapter, AppColors.accent),
              ],
            ),
            if (card.intro != null) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Mascot(size: 64, mood: MascotMood.think),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SpeechBubble(
                      child: MathText(
                        card.intro!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            _Section(
              emoji: '💡',
              title: '핵심 요약',
              color: AppColors.sunny,
              show: card.points.isNotEmpty,
              child: _Bullets(items: card.points, numbered: true),
            ),
            _Section(
              emoji: '🧮',
              title: '공식',
              color: AppColors.primary,
              show: card.formulas.isNotEmpty,
              child: _FormulaList(items: card.formulas),
            ),
            _Section(
              emoji: '✅',
              title: '조건 · 주의',
              color: AppColors.accent,
              show: card.conditions.isNotEmpty,
              child: _Bullets(items: card.conditions),
            ),
            _Section(
              emoji: '📝',
              title: '예시',
              color: const Color(0xFF4DA8E8),
              show: card.examples.isNotEmpty,
              child: _ExampleList(items: card.examples),
            ),
            _Section(
              emoji: '⚠️',
              title: '자주 하는 실수',
              color: wrong,
              show: card.mistakes.isNotEmpty,
              child: _Bullets(items: card.mistakes, color: wrong, mark: '✕'),
            ),
            _Section(
              emoji: '🎯',
              title: '미니 O / X 퀴즈',
              color: AppColors.pink,
              show: card.quiz.isNotEmpty,
              child: _MiniQuiz(items: card.quiz),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 2),
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
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
            child: const Text('이 개념 문제 풀러 가기 →'),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    final p = Pastel.of(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.fg,
        ),
      ),
    );
  }
}

/// 이모지 배지 + 제목을 단 색깔 섹션 카드. [show]가 false면 아무것도 그리지 않는다.
class _Section extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;
  final bool show;
  final Widget child;

  const _Section({
    required this.emoji,
    required this.title,
    required this.color,
    required this.show,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = Pastel.of(context, color);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(p.bg, theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border, width: 2),
          boxShadow: [BoxShadow(color: p.border, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiBadge(emoji, color: color, size: 38),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: p.fg),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// 불릿 목록. [numbered]면 번호 동그라미, [mark]가 있으면 그 기호, 아니면 점.
class _Bullets extends StatelessWidget {
  final List<String> items;
  final Color? color;
  final bool numbered;
  final String? mark;

  const _Bullets({
    required this.items,
    this.color,
    this.numbered = false,
    this.mark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dot = color ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: numbered || mark != null
                        ? dot.withValues(alpha: 0.9)
                        : dot.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: numbered
                      ? Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : mark != null
                      ? Text(
                          mark!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                Expanded(
                  child: MathText(
                    items[i],
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 공식: 흰 카드 + 왼쪽 포인트 띠로 눈에 띄게.
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 7, color: scheme.primary),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: MathText(
                        f,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 예시: Q 배지 + 질문 → "풀이" 라벨 + 풀이.
class _ExampleList extends StatelessWidget {
  final List<ConceptExample> items;

  const _ExampleList({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DA8E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '예${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: MathText(
                        items[i].prompt,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (items[i].solution.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '풀이',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        MathText(
                          items[i].solution,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            height: 1.6,
                          ),
                        ),
                      ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 2,
          color: !answered
              ? scheme.outlineVariant
              : (isCorrect ? correctColor : wrongColor).withValues(alpha: 0.7),
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
                Text(
                  isCorrect ? '🎉' : '🤔',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCorrect
                            ? '정답이에요'
                            : '아쉬워요, 정답은 ${quiz.answer ? "O" : "X"}',
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
    final neutral = label == 'O' ? AppColors.accent : AppColors.wrong;
    final base = tint ?? (selected ? scheme.primary : neutral);
    final active = selected || tint != null;
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: active ? base : scheme.outlineVariant,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: active ? base.withValues(alpha: 0.14) : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? base : scheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: active ? base : neutral,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
