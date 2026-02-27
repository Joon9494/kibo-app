// =====================================================
// 📁 lib/core/theme_provider.dart
// 역할: 선택된 팔레트를 앱 전체에 반영 + SharedPreferences 저장
//       앱 시작 시 미리 로드 → 깜빡임 없음
// =====================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

// ✅ SharedPreferences 인스턴스를 앱 시작 시 1회만 생성 후 주입
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main()에서 override 필요');
});

class ThemeNotifier extends Notifier<KiboPalette> {
  static const _key = 'kibo_palette';

  // ✅ build()는 동기 — prefs 인스턴스를 주입받아 즉시 반환 (깜빡임 없음)
  @override
  KiboPalette build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_key);
    if (saved == null) return KiboPalette.classic;
    return KiboPalette.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => KiboPalette.classic,
    );
  }

  // ✅ 저장소 인스턴스 재사용 — 중복 호출 없음
  Future<void> setPalette(KiboPalette palette) async {
    state = palette;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, palette.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, KiboPalette>(ThemeNotifier.new);