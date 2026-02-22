import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: KiboApp(),
    ),
  );
}

class KiboApp extends StatelessWidget {
  const KiboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KIBO',
      debugShowCheckedModeBanner: false,
      theme: KiboTheme.light,
      darkTheme: KiboTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}