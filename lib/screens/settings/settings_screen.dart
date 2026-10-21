import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/cute.dart';
import '../../widgets/section_header.dart';
import '../../widgets/ads/banner_ad_slot.dart';
import 'account_section.dart';
import 'inquiry_screen.dart';
import 'shop_section.dart';

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
          const AccountSection(),
          const ShopSection(),
          const SectionHeader('알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  secondary: _lead(
                    Icons.notifications_active_rounded,
                    AppColors.streak,
                  ),
                  title: const Text(
                    '학습 리마인더',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('매일 정해진 시간에 한 번 알려드려요'),
                  value: settings.notificationsOn,
                  onChanged: (v) => _toggleReminder(context, ref, v),
                ),
                if (settings.notificationsOn) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: _lead(Icons.schedule_rounded, AppColors.primary),
                    title: const Text(
                      '알림 시간',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(
                      _fmtTime(settings.reminderHour, settings.reminderMinute),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    onTap: () => _pickTime(context, ref, settings),
                  ),
                ],
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  secondary: _lead(Icons.emoji_events_rounded, AppColors.sunny),
                  title: const Text(
                    '주간시험 리마인더',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('매주 일요일, 같은 시각에 알려드려요'),
                  value: settings.weeklyTestReminderOn,
                  onChanged: (v) => _toggleWeeklyTestReminder(context, ref, v),
                ),
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
                  label: Text('${_goalEmoji(g)} ${g.label}'),
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
          Row(
            children: [
              for (final (mode, emoji, label) in [
                (ThemeMode.system, '🌗', '자동'),
                (ThemeMode.light, '☀️', '라이트'),
                (ThemeMode.dark, '🌙', '다크'),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: mode == ThemeMode.dark ? 0 : 10,
                    ),
                    child: _themeChoice(ref, settings, mode, emoji, label),
                  ),
                ),
            ],
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
                  leading: _lead(Icons.mail_outline_rounded, AppColors.primary),
                  title: const Text(
                    '문의하기',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InquiryScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _lead(Icons.privacy_tip_outlined, AppColors.accent),
                  title: const Text(
                    '개인정보처리방침',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      _openUrl(context, 'https://duo.jiny.shop/mfa/privacy'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _lead(Icons.description_outlined, AppColors.accent),
                  title: const Text(
                    '이용약관',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      _openUrl(context, 'https://duo.jiny.shop/mfa/terms'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _lead(
                    Icons.currency_exchange_rounded,
                    AppColors.streak,
                  ),
                  title: const Text(
                    '환불 안내',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      _openUrl(context, 'https://duo.jiny.shop/mfa/refund'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _lead(Icons.help_outline_rounded, AppColors.pink),
                  title: const Text(
                    '지원',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      _openUrl(context, 'https://duo.jiny.shop/mfa/support'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _lead(Icons.info_outline_rounded, AppColors.primary),
                  title: const Text(
                    '앱 정보',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 목록 아이콘: 파스텔 동그라미 배경.
  Widget _lead(IconData icon, Color color) => Builder(
    builder: (context) {
      final p = Pastel.of(context, color);
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: p.bg,
          shape: BoxShape.circle,
          border: Border.all(color: p.border, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: p.fg),
      );
    },
  );

  /// 앱 디자인 언어에 맞춘 커스텀 '앱 정보' 다이얼로그.
  void _showAboutDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const AboutAppDialog());
  }

  String _goalEmoji(DailyGoal g) => switch (g) {
    DailyGoal.one => '🌱',
    DailyGoal.three => '🌿',
    DailyGoal.five => '🌳',
    DailyGoal.free => '🎈',
  };

  String _fmtTime(int h, int m) {
    final period = h < 12 ? '오전' : '오후';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$period $h12:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool v,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    if (!v) {
      notifier.toggleNotifications(false);
      return;
    }
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('알림 권한이 꺼져 있어요. 기기 설정에서 허용해 주세요')),
      );
      return;
    }
    notifier.toggleNotifications(true);
    final s = ref.read(settingsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '매일 ${_fmtTime(s.reminderHour, s.reminderMinute)}에 알려드릴게요',
        ),
      ),
    );
  }

  Future<void> _toggleWeeklyTestReminder(
    BuildContext context,
    WidgetRef ref,
    bool v,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(settingsProvider.notifier);
    if (!v) {
      notifier.toggleWeeklyTestReminder(false);
      return;
    }
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('알림 권한이 꺼져 있어요. 기기 설정에서 허용해 주세요')),
      );
      return;
    }
    notifier.toggleWeeklyTestReminder(true);
    messenger.showSnackBar(
      const SnackBar(content: Text('매주 일요일에 주간시험을 알려드릴게요')),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    Settings s,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (picked == null) return;
    ref
        .read(settingsProvider.notifier)
        .setReminderTime(picked.hour, picked.minute);
    messenger.showSnackBar(
      SnackBar(
        content: Text('매일 ${_fmtTime(picked.hour, picked.minute)}에 알려드릴게요'),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('open failed');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('페이지를 열 수 없어요: $url')));
    }
  }

  Widget _themeChoice(
    WidgetRef ref,
    Settings settings,
    ThemeMode mode,
    String emoji,
    String label,
  ) {
    final selected = settings.themeMode == mode;
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final color = selected ? scheme.primary : scheme.outlineVariant;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: color, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: selected ? scheme.primaryContainer : scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: color, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  ref.read(settingsProvider.notifier).setThemeMode(mode),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 앱 디자인 언어에 맞춘 커스텀 '앱 정보' 다이얼로그.
///
/// Dialog 자식은 너비 제약이 느슨/무한이라 Row+Expanded·Divider·꽉 찬 버튼이
/// "infinite width"로 터진다. 그래서 콘텐츠에 **타이트한 너비 앵커**(SizedBox)를
/// 주고, 액션 버튼은 Expanded 대신 세로 스택(stretch)으로 배치한다.
class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key});

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  String _appVersion = ''; // pubspec 버전을 네이티브에서 읽어온다(하드코딩 불일치 방지)

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _appVersion = info.version);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final appName = AppLocalizations.of(context).appName;
    // 화면 폭 - 다이얼로그 여백을 고려해 최대 320으로 고정 너비 산출.
    final available = MediaQuery.sizeOf(context).width - 72;
    final width = available > 320 ? 320.0 : available;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 브랜드 배지 (앱 아이콘 이미지)
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      // 자산 로드 실패 시 그라데이션 배지로 폴백.
                      errorBuilder: (context, error, stack) => Container(
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Text(
                          'x²',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              // 버전 칩
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _appVersion.isEmpty ? '버전' : '버전 $_appVersion',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '어른이 다시 시작하는 수학 루틴',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              // 액션: 세로 스택 (Expanded 미사용 → 무한 너비 회피)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showLicensePage(
                    context: context,
                    applicationName: appName,
                    applicationVersion: _appVersion,
                  );
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('오픈소스 라이선스'),
              ),
              const SizedBox(height: 2),
              Text(
                '© 2026 JinSoft',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
