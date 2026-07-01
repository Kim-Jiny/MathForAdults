import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/difficulty.dart';
import '../../models/math_problem.dart';
import '../../state/app_state.dart';
import 'quiz_screen.dart';

/// 풀이 세션 시작 헬퍼. 콘텐츠를 lazy 로드한 뒤 QuizScreen을 push 한다.
class QuizLauncher {
  QuizLauncher._();

  /// 이미 문제 객체를 가진 경우(복습 등) 즉시 시작.
  static void startWith(
    BuildContext context,
    List<MathProblem> problems, {
    String? title,
  }) {
    if (problems.isEmpty) {
      _toast(context, '아직 준비된 문제가 없어요');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(problems: problems, sessionTitle: title),
      ),
    );
  }

  /// 세부 단원(+난이도) 세션. 과목 파일을 lazy 로드.
  static Future<void> startLesson(
    BuildContext context,
    WidgetRef ref, {
    required String subject,
    required String chapter,
    required String lesson,
    Difficulty? difficulty,
    String? title,
  }) async {
    final problems = await _withLoading(
      context,
      ref
          .read(contentRepositoryProvider)
          .loadLesson(subject, chapter, lesson, difficulty: difficulty),
    );
    if (problems == null || !context.mounted) return;
    startWith(context, problems, title: title ?? lesson);
  }

  /// 수능 점수대(2/3/4점) → 난이도 매핑.
  static const Map<int, List<Difficulty>> csatBands = {
    2: [Difficulty.conceptCheck, Difficulty.basic],
    3: [Difficulty.typical, Difficulty.applied],
    4: [Difficulty.csatBasic, Difficulty.csatReal],
  };

  /// 수능 랜덤 세션.
  static Future<void> startCsat(
    BuildContext context,
    WidgetRef ref,
    int points,
  ) async {
    final bands = csatBands[points] ?? const [];
    final problems = await _withLoading(
      context,
      ref.read(contentRepositoryProvider).randomByDifficulties(bands),
    );
    if (problems == null || !context.mounted) return;
    startWith(context, problems, title: '수능 랜덤 · $points점');
  }

  /// 로딩 인디케이터를 띄우고 future를 기다린다.
  static Future<List<MathProblem>?> _withLoading(
    BuildContext context,
    Future<List<MathProblem>> future,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      return await future;
    } catch (_) {
      if (context.mounted) {
        _toast(context, '문제를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
      return null;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  static void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
