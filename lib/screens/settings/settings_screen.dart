import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/ads/banner_ad_slot.dart';
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
          const SectionHeader('알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text('학습 리마인더',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('매일 정해진 시간에 한 번 알려드려요'),
                  value: settings.notificationsOn,
                  onChanged: (v) => _toggleReminder(context, ref, v),
                ),
                if (settings.notificationsOn) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.schedule_rounded, size: 20),
                    title: const Text('알림 시간',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(
                      _fmtTime(settings.reminderHour, settings.reminderMinute),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary),
                    ),
                    onTap: () => _pickTime(context, ref, settings),
                  ),
                ],
              ],
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
          const BannerAdSlot(
            placement: BannerPlacement.settings,
            margin: EdgeInsets.symmetric(vertical: 10),
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

  String _fmtTime(int h, int m) {
    final period = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$period $h12:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref, bool v) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    if (!v) {
      notifier.toggleNotifications(false);
      return;
    }
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      messenger.showSnackBar(const SnackBar(
          content: Text('알림 권한이 꺼져 있어요. 기기 설정에서 허용해 주세요')));
      return;
    }
    notifier.toggleNotifications(true);
    final s = ref.read(settingsProvider);
    messenger.showSnackBar(SnackBar(
        content: Text('매일 ${_fmtTime(s.reminderHour, s.reminderMinute)}에 알려드릴게요')));
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, Settings s) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (picked == null) return;
    ref.read(settingsProvider.notifier).setReminderTime(picked.hour, picked.minute);
    messenger.showSnackBar(SnackBar(
        content: Text('매일 ${_fmtTime(picked.hour, picked.minute)}에 알려드릴게요')));
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
