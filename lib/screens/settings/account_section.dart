import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../state/auth_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

const _kakaoYellow = Color(0xFFFEE500);
const _kakaoBrown = Color(0xFF191919);
const _buttonRadius = BorderRadius.all(Radius.circular(16));

/// 설정 화면의 "계정" 섹션 — 로그인하면 학습기록·설정이 계정 하나로 여러 기기에서
/// 공유된다. 로그인하지 않아도 앱은 지금처럼 완전히 로컬로 동작한다.
class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (next.conflict != null && prev?.conflict == null) {
        _showConflictDialog(context, ref, next.conflict!);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('계정'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: auth.loggedIn
              ? _LoggedInView(auth: auth)
              : _LoggedOutView(syncing: auth.syncing),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _LoggedOutView extends ConsumerWidget {
  final bool syncing;
  const _LoggedOutView({required this.syncing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(authProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '로그인하면 학습기록을 다른 기기와 공유할 수 있어요. 로그인하지 않아도 이 기기에서는 그대로 사용할 수 있어요.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          _GoogleButton(enabled: !syncing, onTap: notifier.loginWithGoogle),
          if (Platform.isIOS) ...[
            const SizedBox(height: 10),
            SignInWithAppleButton(
              onPressed: syncing ? null : notifier.loginWithApple,
              text: 'Apple로 로그인',
              height: 54,
              borderRadius: _buttonRadius,
            ),
          ],
          const SizedBox(height: 10),
          _KakaoButton(enabled: !syncing, onTap: notifier.loginWithKakao),
          if (syncing) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 구글 브랜드 가이드(흰 배경 + 회색 테두리 + 정식 4색 G 로고) 준수 버튼.
class _GoogleButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _GoogleButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        height: 54,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: _buttonRadius,
            side: BorderSide(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/google_logo.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Google로 로그인',
                  style: TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카카오 브랜드 가이드(시그니처 옐로우 #FEE500 + 검정 말풍선) 준수 버튼.
class _KakaoButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _KakaoButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: SizedBox(
        height: 54,
        child: Material(
          color: _kakaoYellow,
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_rounded, color: _kakaoBrown, size: 20),
                SizedBox(width: 12),
                Text(
                  '카카오로 로그인',
                  style: TextStyle(
                    color: _kakaoBrown,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final AuthState auth;
  const _LoggedInView({required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(authProvider.notifier);
    final nickname = auth.user?.nickname?.trim();
    final displayName = (nickname == null || nickname.isEmpty)
        ? (auth.user?.email ?? '내 계정')
        : nickname;
    return Column(
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text('$displayName님',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_syncLabel(auth.lastSyncedAt)),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '닉네임 변경',
            onPressed: () => _editNickname(context, ref, nickname ?? ''),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: auth.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          title: const Text('지금 동기화',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: auth.syncing ? null : notifier.syncNow,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('로그아웃',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onTap: auth.syncing ? null : notifier.logout,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: Icon(Icons.person_remove_outlined,
              color: Theme.of(context).colorScheme.error),
          title: Text('회원탈퇴',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error)),
          onTap: auth.syncing ? null : () => _confirmDeleteAccount(context, ref),
        ),
      ],
    );
  }

  String _syncLabel(DateTime? at) {
    if (at == null) return '아직 동기화하지 않았어요';
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '마지막 동기화: ${at.month}/${at.day} $h:$m';
  }

  Future<void> _editNickname(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '다른 사람에게 보이지 않아요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == current) return;
    final ok = await ref.read(authProvider.notifier).updateNickname(result);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('닉네임을 바꿨어요')));
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '계정과 클라우드에 저장된 학습기록·구매 연결 정보가 삭제돼요. 이 기기에 남아있는 학습기록은 '
          '그대로 유지되고(게스트로 계속 사용 가능), 되돌릴 수 없어요.\n\n정말 탈퇴할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(authProvider.notifier).deleteAccount();
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('탈퇴 처리됐어요')));
    }
  }
}

/// 로그인 직후 이 기기와 계정(클라우드) 기록이 둘 다 있을 때 — 조용히 합치지 않고
/// 합치기/계정 기록으로 교체/취소 중에서 고르게 한다.
Future<void> _showConflictDialog(
    BuildContext context, WidgetRef ref, ProgressConflict conflict) async {
  final notifier = ref.read(authProvider.notifier);
  final available = MediaQuery.sizeOf(context).width - 72;
  final width = available > 340 ? 340.0 : available;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '다른 기기 기록이 있어요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  '이 계정에 저장된 학습기록이 이 기기랑 달라요. 어떻게 할까요?\n\n'
                  '이 기기: ${conflict.localStats.totalSolved}문제 풀이\n'
                  '계정(클라우드): ${conflict.cloudStats.totalSolved}문제 풀이',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    notifier.resolveConflict(ConflictChoice.merge);
                  },
                  child: const Text('합치기 (추천)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    notifier.resolveConflict(ConflictChoice.useCloud);
                  },
                  child: const Text('계정 기록으로 교체'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    notifier.resolveConflict(ConflictChoice.cancel);
                  },
                  child: const Text('취소하고 로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
