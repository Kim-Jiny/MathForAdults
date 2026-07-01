import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/inquiry_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';

/// 문의하기: 작성 → 서버 전송, 내 문의·답변 조회.
class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen> {
  final _content = TextEditingController();
  bool _sending = false;
  late Future<List<MyInquiry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(inquiryServiceProvider).fetchMine();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _reload() {
    final future = ref.read(inquiryServiceProvider).fetchMine();
    setState(() {
      _future = future;
    });
  }

  Future<void> _send() async {
    final text = _content.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(inquiryServiceProvider).submit(text);
      if (!mounted) return;
      _content.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문의가 접수됐어요. 답변은 여기서 확인할 수 있어요')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송에 실패했어요. 잠시 후 다시 시도해 주세요')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('문의하기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text('궁금한 점이나 오류 제보를 남겨주세요. 답변은 이 화면에서 확인할 수 있어요.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            maxLines: 5,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: '문의 내용을 입력하세요',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16)),
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_sending || _content.text.trim().isEmpty) ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('문의 보내기'),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('내 문의',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<MyInquiry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _hint(theme, '문의 목록을 불러오지 못했어요');
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return _hint(theme, '아직 보낸 문의가 없어요');
              }
              return Column(
                children: list.map((q) => _inquiryTile(theme, q)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _hint(ThemeData theme, String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(msg,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );

  Widget _inquiryTile(ThemeData theme, MyInquiry q) {
    final green = AppColors.correctOf(theme.brightness);
    final color = q.replied ? green : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(q.replied ? '답변완료' : '대기중',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
                if (q.createdAt != null)
                  Text(_date(q.createdAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            Text(q.content,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            if (q.replied && (q.reply?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('답변',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: green, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(q.reply!,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime d) {
    final l = d.toLocal();
    return '${l.year}.${l.month.toString().padLeft(2, '0')}.${l.day.toString().padLeft(2, '0')}';
  }
}
