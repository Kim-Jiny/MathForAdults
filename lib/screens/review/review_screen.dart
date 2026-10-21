import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/difficulty.dart';
import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cute.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/mascot.dart';
import '../../widgets/math_symbols.dart';
import '../../widgets/section_header.dart';
import '../quiz/quiz_launcher.dart';

/// 다시풀기 탭: 틀린 문제 목록 + 필터 + 오늘 다시 풀 문제.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _subject;
  Difficulty? _difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wrong = ref.watch(wrongProblemsProvider);

    if (wrong.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('다시 풀 문제')),
        body: _empty(theme),
      );
    }

    final subjects = wrong.map((p) => p.subject).toSet().toList();
    // 선택한 과목의 마지막 오답을 풀어 칩이 사라지면 필터가 남아 빈 화면이 되므로 해제.
    if (_subject != null && !subjects.contains(_subject)) _subject = null;
    final filtered = wrong.where((p) {
      if (_subject != null && p.subject != _subject) return false;
      if (_difficulty != null && p.difficulty != _difficulty) return false;
      return true;
    }).toList();
    final today = wrong.take(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('다시 풀 문제')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // 오늘 다시 풀 문제: 마스코트가 응원
          AppCard(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Column(
              children: [
                Row(
                  children: [
                    const Mascot(size: 64, mood: MascotMood.think),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '틀린 문제 ${wrong.length}개',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '오늘은 ${today.length}문제만 가볍게 복습해요',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => QuizLauncher.startWith(
                      context,
                      today,
                      title: '오늘 다시 풀기',
                    ),
                    child: const Text('지금 복습 시작 →'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 필터
          const SectionHeader('틀린 문제'),
          _filterRow(subjects),
          const SizedBox(height: 12),

          ...filtered.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _wrongTile(p),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow(List<String> subjects) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('전체', _subject == null && _difficulty == null, () {
            setState(() {
              _subject = null;
              _difficulty = null;
            });
          }),
          ...subjects.map(
            (s) => _chip(s, _subject == s, () {
              setState(() => _subject = _subject == s ? null : s);
            }),
          ),
          const SizedBox(width: 4),
          ...[Difficulty.csatBasic, Difficulty.csatReal].map(
            (d) => _chip(d.label, _difficulty == d, () {
              setState(() => _difficulty = _difficulty == d ? null : d);
            }),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
        selectedColor: theme.colorScheme.primary,
        showCheckmark: false,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
    );
  }

  Widget _wrongTile(MathProblem p) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiBadge('🤔', color: p.difficulty.color, size: 34),
              const SizedBox(width: 10),
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
          const SizedBox(height: 8),
          Text(
            p.question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '예상 ${p.estimatedTime}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () =>
                    QuizLauncher.startWith(context, [p], title: '다시 풀기'),
                child: const Text('재도전'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolConfetti(
            child: Mascot(size: 110, mood: MascotMood.happy, bounce: true),
          ),
          const SizedBox(height: 16),
          Text(
            '다시 풀 문제가 없어요',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '틀린 문제는 여기에 모여요. 부담 없이 한 문제씩!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
