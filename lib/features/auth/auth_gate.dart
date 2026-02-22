// =====================================================
// 📁 lib/features/auth/auth_gate.dart
// 역할: 로그인 상태 감지 → 화면 자동 분기
//       로그인 O → 홈 / 로그인 X → 로그인 화면
// =====================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../calendar/home_screen.dart'; // ← 이 줄이 핵심

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {

        // 로그인 상태 확인 중
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 에러 발생 시
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('오류가 발생했습니다.')),
          );
        }

        // 로그인 O → 홈
        if (snapshot.data != null) {
          return HomeScreen();
        }

        // 로그인 X → 로그인 화면
        return const LoginScreen();
      },
    );
  }
}