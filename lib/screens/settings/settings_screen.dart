import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import 'inquiry_screen.dart';

/// 설정 탭: 알림 / 목표 / 테마 / 문의 / 앱 정보.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const SectionHeader('계정'),
          const _AccountCard(),
          const SizedBox(height: 22),
          const SectionHeader('알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('학습 리마인더',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('하루 한 번, 부담 없이 알려드려요'),
              value: settings.notificationsOn,
              onChanged: notifier.toggleNotifications,
            ),
          ),
          const SizedBox(height: 22),

          const SectionHeader('하루 목표'),
          AppCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: DailyGoal.values.map((g) {
                final selected = settings.dailyGoal == g;
                return ChoiceChip(
                  label: Text(g.label),
                  selected: selected,
                  onSelected: (_) => notifier.setGoal(g),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  selectedColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),

          const SectionHeader('테마'),
          AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _themeTile(ref, settings, ThemeMode.system, '시스템 설정', Icons.brightness_auto),
                _themeTile(ref, settings, ThemeMode.light, '라이트', Icons.light_mode),
                _themeTile(ref, settings, ThemeMode.dark, '다크', Icons.dark_mode),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const SectionHeader('기타'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline_rounded),
                  title: const Text('문의하기',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InquiryScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('개인정보처리방침',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(
                      context, 'https://duo.jiny.shop/mfa/privacy'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('지원',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openUrl(
                      context, 'https://duo.jiny.shop/mfa/support'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('앱 정보',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppLocalizations.of(context).appName,
                    applicationVersion: '1.0.0',
                    applicationLegalese: '어른이 다시 시작하는 수학 루틴',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('open failed');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('페이지를 열 수 없어요: $url')));
    }
  }

  Widget _themeTile(WidgetRef ref, Settings settings, ThemeMode mode,
      String label, IconData icon) {
    final selected = settings.themeMode == mode;
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return ListTile(
        onTap: () => ref.read(settingsProvider.notifier).setThemeMode(mode),
        leading: Icon(icon, size: 20),
        title: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : Icon(Icons.circle_outlined, color: scheme.outlineVariant),
      );
    });
  }
}

/// 계정 카드: 로그아웃 상태면 소셜 로그인 버튼, 로그인 상태면 계정·동기화·로그아웃.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final st = ref.watch(accountProvider);
    final notifier = ref.read(accountProvider.notifier);
    final busy = st.phase == SyncPhase.working;

    if (!st.loggedIn) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로그인하고 백업·동기화',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('로그인하면 진도·출석·오답이 기기 간에 안전하게 유지돼요. (선택)',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: busy ? null : notifier.signInWithApple,
              icon: const Icon(Icons.apple, size: 20),
              label: const Text('Apple로 로그인'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: busy ? null : notifier.signInWithGoogle,
              icon: const Text('G',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              label: const Text('Google로 로그인'),
            ),
            if (busy) ...[
              const SizedBox(height: 10),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      );
    }

    final a = st.account!;
    final label = a.email ?? a.nickname ?? '로그인됨';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      st.phase == SyncPhase.done
                          ? '동기화됨'
                          : st.phase == SyncPhase.error
                              ? (st.message ?? '동기화 오류')
                              : '백업·동기화 사용 중',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: st.phase == SyncPhase.error
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : notifier.syncNow,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('지금 동기화'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: busy ? null : notifier.signOut,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
