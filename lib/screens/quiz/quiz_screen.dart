import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/math_text.dart';
import 'explanation_panel.dart';
import 'session_result.dart';

/// 문제 풀이 화면 (앱의 핵심). 한 세션 = 문제 리스트.
class QuizScreen extends ConsumerStatefulWidget {
  final List<MathProblem> problems;
  final String? sessionTitle;

  const QuizScreen({super.key, required this.problems, this.sessionTitle});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _index = 0;
  int? _selected; // 선택한 보기 (choice)
  final _shortController = TextEditingController();
  bool _checked = false;
  bool _lastCorrect = false;
  int _correctCount = 0;
  bool _finished = false;

  MathProblem get _problem => widget.problems[_index];
  int get _total => widget.problems.length;

  @override
  void dispose() {
    _shortController.dispose();
    super.dispose();
  }

  void _commit(bool correct) {
    setState(() {
      _checked = true;
      _lastCorrect = correct;
    });
    if (correct) _correctCount++;
    ref.read(statsProvider.notifier).recordAnswer(_problem, correct: correct);
  }

  void _onSelect(int i) {
    if (_checked) return;
    _selected = i;
    _commit(i == _problem.answerIndex);
  }

  void _checkShort() {
    if (_checked) return;
    final text = _shortController.text.trim();
    if (text.isEmpty) return;
    _commit(_problem.isCorrect(text));
  }

  void _resetForCurrent() {
    _selected = null;
    _shortController.clear();
    _checked = false;
    _lastCorrect = false;
  }

  void _next() {
    if (_index + 1 >= _total) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _resetForCurrent();
    });
  }

  void _retryCurrent() => setState(_resetForCurrent);

  Future<void> _openSimilar() async {
    final p = _problem;
    final lessonProblems = await ref.read(contentRepositoryProvider).loadLesson(
          p.subject,
          p.chapter,
          p.lesson,
        );
    final pool = lessonProblems.where((q) => q.id != p.id).toList();
    if (!mounted) return;
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비슷한 문제가 아직 없어요')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          problems: pool,
          sessionTitle: '${p.lesson} · 비슷한 문제',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return SessionResult(
        total: _total,
        correct: _correctCount,
        onRetrySession: () => setState(() {
          _index = 0;
          _resetForCurrent();
          _correctCount = 0;
          _finished = false;
        }),
      );
    }

    final theme = Theme.of(context);
    final p = _problem;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionTitle ?? p.chapter),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_index + (_checked ? 1 : 0)) / _total,
            minHeight: 3,
            backgroundColor: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.breadcrumb,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DifficultyBadge(p.difficulty, compact: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('문제 ${_index + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          )),
                      Text(' / $_total',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      const Spacer(),
                      if (p.type == ProblemType.short)
                        _typePill(theme, '단답형')
                      else
                        _typePill(theme, '객관식'),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('예상 ${p.estimatedTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MathText(
                    p.question,
                    style: theme.textTheme.titleLarge?.copyWith(
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (p.type == ProblemType.short)
                    _shortInput(theme)
                  else
                    ...List.generate(p.choices.length, (i) => _choiceTile(i)),
                  if (_checked) ...[
                    const SizedBox(height: 20),
                    ExplanationPanel(
                      problem: p,
                      correct: _lastCorrect,
                      onSimilar: _openSimilar,
                    ),
                  ],
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _typePill(ThemeData theme, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            )),
      );

  Widget _shortInput(ThemeData theme) {
    final scheme = theme.colorScheme;
    Color border = scheme.outlineVariant;
    if (_checked) {
      border = _lastCorrect ? const Color(0xFF2E9E6B) : const Color(0xFFD66A5F);
    }
    return TextField(
      controller: _shortController,
      enabled: !_checked,
      autofocus: false,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _checkShort(),
      style: theme.textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: '정답을 입력하세요 (예: 12, 3/2, −5)',
        filled: true,
        fillColor: scheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }

  Widget _choiceTile(int i) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAnswer = i == _problem.answerIndex;
    final isSelected = _selected == i;

    Color border = scheme.outlineVariant;
    Color bg = scheme.surface;
    Color numBg = scheme.surfaceContainerHighest;
    Color numFg = scheme.onSurfaceVariant;
    Widget? trailing;

    if (_checked) {
      if (isAnswer) {
        border = const Color(0xFF2E9E6B);
        bg = const Color(0xFFE7F5EE);
        numBg = const Color(0xFF2E9E6B);
        numFg = Colors.white;
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF2E9E6B));
      } else if (isSelected) {
        border = const Color(0xFFD66A5F);
        bg = const Color(0xFFFBECEA);
        numBg = const Color(0xFFD66A5F);
        numFg = Colors.white;
        trailing =
            const Icon(Icons.cancel_rounded, color: Color(0xFFD66A5F));
      }
    } else if (isSelected) {
      border = scheme.primary;
      numBg = scheme.primary;
      numFg = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onSelect(i),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: border, width: _checked && isAnswer ? 1.8 : 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: numBg, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: numFg, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: MathText(
                    _problem.choices[i],
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final theme = Theme.of(context);
    final isLast = _index + 1 >= _total;
    final isShort = _problem.type == ProblemType.short;

    Widget child;
    if (_checked) {
      child = Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _retryCurrent,
              child: const Text('다시 풀기'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: FilledButton(
              onPressed: _next,
              child: Text(isLast ? '결과 보기' : '다음 문제'),
            ),
          ),
        ],
      );
    } else if (isShort) {
      final canCheck = _shortController.text.trim().isNotEmpty;
      child = FilledButton(
        onPressed: canCheck ? _checkShort : null,
        child: const Text('채점하기'),
      );
    } else {
      child = Text(
        '정답을 선택하면 바로 채점돼요',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: child,
    );
  }
}
