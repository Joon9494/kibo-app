// =====================================================
// 📁 lib/core/theme.dart
// 역할: KIBO 앱 전체 테마 정의
//       4가지 팔레트 지원 — 설정에서 선택 가능
// =====================================================

import 'package:flutter/material.dart';

enum KiboPalette {
  classic,
  indigoAmber,
  mauveApricot,
  forestBeige,
}

extension KiboPaletteInfo on KiboPalette {
  String get label {
    switch (this) {
      case KiboPalette.classic:      return '클래식 (기본)';
      case KiboPalette.indigoAmber:  return '인디고 앰버';
      case KiboPalette.mauveApricot: return '모브 살구';  // ✅ 오타 수정
      case KiboPalette.forestBeige:  return '포레스트 베이지';
    }
  }

  Color get primary {
    switch (this) {
      case KiboPalette.classic:      return const Color(0xFF1D4ED8);
      case KiboPalette.indigoAmber:  return const Color(0xFF3D3580);
      case KiboPalette.mauveApricot: return const Color(0xFF6B5B8E);
      case KiboPalette.forestBeige:  return const Color(0xFF3D6B52);
    }
  }

  Color get secondary {
    switch (this) {
      case KiboPalette.classic:      return const Color(0xFF0D9488);
      case KiboPalette.indigoAmber:  return const Color(0xFFF2A93B);
      case KiboPalette.mauveApricot: return const Color(0xFFF4A27A);
      case KiboPalette.forestBeige:  return const Color(0xFFE8C99A);
    }
  }

  // ✅ background → surfaceColor 로 명칭 변경 (Deprecated 방지)
  Color get surfaceColor {
    switch (this) {
      case KiboPalette.classic:      return const Color(0xFFF8FAFC);
      case KiboPalette.indigoAmber:  return const Color(0xFFFAFAF7);
      case KiboPalette.mauveApricot: return const Color(0xFFFDF8F4);
      case KiboPalette.forestBeige:  return const Color(0xFFF8F6F2);
    }
  }
}

class KiboTheme {
  // 기존 코드 호환용
  static const Color navy = Color(0xFF1B2F5B);
  static const Color blue = Color(0xFF1D4ED8);
  static const Color teal = Color(0xFF0D9488);

  static ThemeData buildLight(KiboPalette palette) {
    final primary   = palette.primary;
    final secondary = palette.secondary;
    final surface   = palette.surfaceColor; // ✅ surfaceColor 사용

    // ✅ background / onBackground 완전 제거 → surface / onSurface 통합
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1A1A2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface, // ✅ surface 사용
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,       // ✅ surface 사용
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withOpacity(0.08),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get light => buildLight(KiboPalette.classic);
  static ThemeData get dark  => buildLight(KiboPalette.classic);
}