import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exam.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import 'exam_builder.dart';
import 'mock_exam_screen.dart';

/// 모의수능 응시 설정: 선택과목 + 프리셋.
class MockExamSetupScreen extends ConsumerStatefulWidget {
  const MockExamSetupScreen({super.key});

  @override
  ConsumerState<MockExamSetupScreen> createState() =>
      _MockExamSetupScreenState();
}

class _MockExamSetupScreenState extends ConsumerState<MockExamSetupScreen> {
  String _elective = kElectiveSubjects.last; // 기하 기본? -> 미적분 등 자유
  ExamPreset _preset = ExamPreset.real;
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    final repo = ref.read(contentRepositoryProvider);
    final problems =
        await buildMockExam(repo, elective: _elective, preset: _preset);
    if (!mounted) return;
    setState(() => _loading = false);
    if (problems.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제가 부족해요. 다른 구성을 선택해 주세요')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockExamScreen(
          problems: problems,
          duration: _preset.duration,
          title: '모의수능 · ${_preset.short}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('모의수능')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('실제 수능 수학처럼 공통(수학Ⅰ·Ⅱ) + 선택 1과목으로 출제돼요.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          Text('선택 과목',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: kElectiveSubjects.map((s) {
              final sel = _elective == s;
              return ChoiceChip(
                label: Text(s),
                selected: sel,
                onSelected: (_) => setState(() => _elective = s),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: sel
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                selectedColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text('형식',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...ExamPreset.values.map((p) {
            final sel = _preset == p;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => setState(() => _preset = p),
                color: sel
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : null,
                child: Row(
                  children: [
                    Icon(
                      sel
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: sel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('만점 ${p.totalPoints}점',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _loading ? null : _start,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('응시 시작'),
          ),
          const SizedBox(height: 8),
          Text('시작하면 타이머가 작동하고, 제출 전까지 정답은 보이지 않아요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
