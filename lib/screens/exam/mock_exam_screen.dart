import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/difficulty.dart';
import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import '../../widgets/math_text.dart';
import 'exam_result_view.dart';

/// 모의수능 응시 화면: 시간제한 + 제출 전 정답 비공개 + 일괄 채점.
class MockExamScreen extends ConsumerStatefulWidget {
  final List<MathProblem> problems;
  final Duration duration;
  final String title;

  const MockExamScreen({
    super.key,
    required this.problems,
    required this.duration,
    required this.title,
  });

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  final Map<int, String> _answers = {}; // 문항 index → 응답
  final _shortController = TextEditingController();
  int _index = 0;
  late Duration _remaining;
  Timer? _timer;
  bool _submitted = false;

  List<MathProblem> get _ps => widget.problems;
  MathProblem get _p => _ps[_index];

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        _submit(auto: true);
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
    _syncController();
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  int get _answeredCount => _answers.values.where((v) => v.trim().isNotEmpty).length;

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
                child: const Text('더 풀기')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('제출')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _submit();
  }

  void _submit({bool auto = false}) {
    if (_submitted) return;
    _timer?.cancel();
    final notifier = ref.read(statsProvider.notifier);
    for (var i = 0; i < _ps.length; i++) {
      final resp = _answers[i] ?? '';
      final correct = resp.trim().isNotEmpty && _ps[i].isCorrect(resp);
      notifier.recordAnswer(_ps[i], correct: correct);
    }
    setState(() => _submitted = true);
    if (auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간이 다 되어 자동 제출됐어요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return ExamResultView(
        problems: _ps,
        answers: _answers,
        elapsed: widget.duration - _remaining,
        title: widget.title,
      );
    }

    final theme = Theme.of(context);
    final p = _p;
    final warn = _remaining.inMinutes < 5;

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
                  child: const Text('계속 풀기')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('나가기')),
            ],
          ),
        );
        if (leave == true && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: warn
                      ? const Color(0xFFD66A5F).withValues(alpha: 0.15)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 16,
                        color: warn
                            ? const Color(0xFFD66A5F)
                            : theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(_fmt(_remaining),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: warn
                              ? const Color(0xFFD66A5F)
                              : theme.colorScheme.primary,
                        )),
                  ],
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_index + 1) / _ps.length,
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
                        Text('${_index + 1}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            )),
                        Text(' / ${_ps.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const Spacer(),
                        Text('${p.difficulty.examPoints}점 · ${p.subject}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MathText(p.question,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(height: 1.55, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }

  Widget _choiceTile(int c) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _answers[_index] == '$c';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectChoice(c),
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.6 : 1.2,
              ),
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
                  child: Text('${c + 1}',
                      style: TextStyle(
                          color: selected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: MathText(_p.choices[c],
                        style: theme.textTheme.titleMedium)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBar(ThemeData theme) {
    final isLast = _index + 1 >= _ps.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(1000).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
