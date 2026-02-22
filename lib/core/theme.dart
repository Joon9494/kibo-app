// =====================================================
// 📁 lib/core/theme.dart
// 역할: KIBO 앱 전체의 색상, 폰트, 디자인 규칙 정의
//       라이트 / 다크 모드 둘 다 지원
// =====================================================

import 'package:flutter/material.dart';

class KiboTheme {
  // 키보 브랜드 색상
  static const Color navy = Color(0xFF1B2F5B);  // 타이틀, 강조
  static const Color blue = Color(0xFF1D4ED8);  // 버튼, 링크
  static const Color teal = Color(0xFF0D9488);  // 서브 강조

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : navy,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark  => _base(Brightness.dark);
}