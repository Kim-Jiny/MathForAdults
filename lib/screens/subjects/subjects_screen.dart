import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/curriculum.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/progress_bar.dart';
import 'subject_detail_screen.dart';

/// 단원 탭: 과목 목록.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(statsProvider).subjectProgress;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('단원 선택')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('어디서부터 풀어볼까요?',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ...kCurriculum.map((s) {
            final p = progress[s.name] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SubjectDetailScreen(subject: s)),
                ),
                child: Row(
                  children: [
                    Text(s.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${s.chapters.length}개 단원',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          ProgressBar(value: p),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
