import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/iap_state.dart';
import 'theme/app_theme.dart';

class AdultMathApp extends ConsumerWidget {
  const AdultMathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider).themeMode;
    // authProvider/iapProvider는 둘 다 Riverpod 지연 생성이라, 여기서 한 번 watch해서
    // 앱 첫 프레임부터 로그인 상태 복원 + 인앱결제 구매 스트림 구독이 시작되게 한다.
    // (안 하면 설정 화면을 들어가야만 초기화돼서, 광고 제거를 산 로그인 사용자가
    //  앱을 새로 열었을 때 설정 화면을 안 보면 광고가 다시 뜨는 문제가 생김.)
    ref.watch(authProvider);
    ref.watch(iapProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainShell(),
    );
  }
}
