import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import '../../widgets/exam_parts.dart';
import 'weekly_test_result_screen.dart';

/// 주간시험 응시 화면: 제출 전 정답 비공개 + 일괄 채점(모의수능과 동일 패턴, 타이머 없음).
class WeeklyTestScreen extends ConsumerStatefulWidget {
  final List<MathProblem> problems;

  const WeeklyTestScreen({super.key, required this.problems});

  @override
  ConsumerState<WeeklyTestScreen> createState() => _WeeklyTestScreenState();
}

class _WeeklyTestScreenState extends ConsumerState<WeeklyTestScreen> {
  final Map<int, String> _answers = {}; // 문항 index → 응답
  final _shortController = TextEditingController();
  int _index = 0;
  bool _submitted = false;

  List<MathProblem> get _ps => widget.problems;
  MathProblem get _p => _ps[_index];

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void dispose() {
    _shortController.dispose();
    super.dispose();
  }

  void _syncController() {
    if (_p.type == ProblemType.short) {
      _shortController.text = _answers[_index] ?? '';
    }
  }

  void _go(int i) {
    if (i < 0 || i >= _ps.length) return;
    setState(() => _index = i);
    _syncController();
  }

  void _selectChoice(int c) => setState(() => _answers[_index] = '$c');

  int get _answeredCount =>
      _answers.values.where((v) => v.trim().isNotEmpty).length;

  Future<void> _confirmSubmit() async {
    final unanswered = _ps.length - _answeredCount;
    if (unanswered > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('제출할까요?'),
          content: Text('아직 $unanswered문항이 비어 있어요. 그래도 제출하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('더 풀기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('제출'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    _submit();
  }

  void _submit() {
    if (_submitted) return;
    final notifier = ref.read(statsProvider.notifier);
    var correctCount = 0;
    final wrongProblems = <MathProblem>[];
    for (var i = 0; i < _ps.length; i++) {
      final resp = _answers[i] ?? '';
      final correct = resp.trim().isNotEmpty && _ps[i].isCorrect(resp);
      if (correct) {
        correctCount++;
      } else {
        wrongProblems.add(_ps[i]);
      }
      notifier.recordAnswer(_ps[i], correct: correct);
    }
    notifier.recordWeeklyTestResult(
      correctCount,
      _ps.length,
      DateTime.now(),
      wrongProblems: wrongProblems,
    );
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return WeeklyTestResultScreen(problems: _ps, answers: _answers);
    }

    final theme = Theme.of(context);
    final p = _p;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('시험을 그만둘까요?'),
            content: const Text('지금 나가면 기록되지 않아요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('계속 풀기'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('나가기'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('이번 주 시험'),
          bottom: examProgressBar(theme, (_index + 1) / _ps.length),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    ExamQuestionCard(
                      index: _index,
                      total: _ps.length,
                      label: p.lesson,
                      question: p.question,
                    ),
                    const SizedBox(height: 20),
                    if (p.type == ProblemType.short)
                      _shortInput(theme)
                    else
                      ...List.generate(p.choices.length, _choiceTile),
                  ],
                ),
              ),
              _navBar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortInput(ThemeData theme) {
    return TextField(
      controller: _shortController,
      onChanged: (v) => _answers[_index] = v,
      textInputAction: TextInputAction.done,
      style: theme.textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: '정답 입력 (예: 12, 3/2, −5)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _choiceTile(int c) => ExamChoiceTile(
    number: c + 1,
    text: _p.choices[c],
    selected: _answers[_index] == '$c',
    onTap: () => _selectChoice(c),
  );

  Widget _navBar(ThemeData theme) {
    final isLast = _index + 1 >= _ps.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExamNavigator(
            count: _ps.length,
            current: _index,
            answered: (i) => (_answers[i] ?? '').trim().isNotEmpty,
            onTap: _go,
          ),
          const SizedBox(height: 10),
          _buttons(theme, isLast),
        ],
      ),
    );
  }

  Widget _buttons(ThemeData theme, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _index == 0 ? null : () => _go(_index - 1),
              child: const Text('이전'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLast
                ? FilledButton(
                    onPressed: _confirmSubmit,
                    child: const Text('제출하기'),
                  )
                : FilledButton(
                    onPressed: () => _go(_index + 1),
                    child: const Text('다음'),
                  ),
          ),
        ],
      ),
    );
  }
}
