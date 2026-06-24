import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/ads/ad_service.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await NotificationService.init();
  // 광고 SDK 초기화(설치 시각 기록 + 전면 광고 프리로드). 첫 프레임을 막지 않도록 await 하지 않음.
  AdService.instance.init(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AdultMathApp(),
    ),
  );
}
