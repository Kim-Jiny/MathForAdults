import 'package:flutter/material.dart';

/// 세션 종료 결과 화면.
class SessionResult extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onRetrySession;

  const SessionResult({
    super.key,
    required this.total,
    required this.correct,
    required this.onRetrySession,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = total == 0 ? 0 : (correct / total * 100).round();
    final (msg, emoji) = _message(rate);

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 결과')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 14),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text('$correct / $total',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        )),
                    const SizedBox(height: 4),
                    Text('정답률 $rate%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetrySession,
                  child: const Text('다시 풀기'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('홈으로'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String) _message(int rate) {
    if (rate >= 90) return ('완벽해요! 다음 단계도 도전해볼까요?', '🎉');
    if (rate >= 70) return ('잘했어요, 감을 잡았네요', '👏');
    if (rate >= 40) return ('좋아요, 해설 본 김에 한 번 더!', '💪');
    return ('천천히 가도 괜찮아요', '🌱');
  }
}
