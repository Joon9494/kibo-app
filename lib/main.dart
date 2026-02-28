// =====================================================
// 📁 lib/main.dart
// =====================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'features/auth/auth_gate.dart';
import 'features/notification/notification_service.dart'; // ✅ 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 앱 시작 전 1회만 초기화 → Provider에 주입
  final prefs = await SharedPreferences.getInstance();

  // ✅ 알림 서비스 초기화
  await NotificationService().initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KiboApp(),
    ),
  );
}

class KiboApp extends ConsumerWidget {
  const KiboApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);
    return MaterialApp(
      title: 'KIBO',
      debugShowCheckedModeBanner: false,
      theme: KiboTheme.buildLight(palette),
      home: const AuthGate(),
    );
  }
}