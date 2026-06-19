import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home/home_screen.dart';
import 'review/review_screen.dart';
import 'settings/settings_screen.dart';
import 'stats/stats_screen.dart';
import 'subjects/subjects_screen.dart';

/// 하단 탭 셸: 홈 / 단원 / 다시풀기 / 기록 / 설정.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  DateTime? _lastBackAt;

  void _openTab(int i) => setState(() => _index = i);

  /// 루트에서 뒤로가기:
  /// - 다른 탭이면 홈 탭으로 복귀
  /// - 홈 탭이면 2초 내 한 번 더 눌러야 종료(안내 토스트)
  void _handleBack() {
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop(); // 앱 종료
      return;
    }
    _lastBackAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('한 번 더 누르면 종료돼요'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onOpenTab: _openTab),
      const SubjectsScreen(),
      const ReviewScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _openTab,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '홈'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: '단원'),
            NavigationDestination(
                icon: Icon(Icons.refresh_outlined),
                selectedIcon: Icon(Icons.refresh_rounded),
                label: '다시풀기'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: '기록'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: '설정'),
          ],
        ),
      ),
    );
  }
}
