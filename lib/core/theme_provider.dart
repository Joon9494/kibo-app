// =====================================================
// 📁 lib/core/theme_provider.dart
// =====================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

// ── SharedPreferences 단일 인스턴스 ───────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main()에서 override 필요');
});

// ── 테마 팔레트 상태 관리 ─────────────────────────────
class ThemeNotifier extends Notifier<KiboPalette> {
  static const _key = 'kibo_palette';

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

  Future<void> setPalette(KiboPalette palette) async {
    state = palette;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, palette.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, KiboPalette>(ThemeNotifier.new);

// ── 브리핑 커스텀 프롬프트 상태 관리 ─────────────────
class BriefingPromptNotifier extends Notifier<String> {
  static const _key = 'kibo_briefing_prompt';

  @override
  String build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '';
  }

  Future<void> setPrompt(String prompt) async {
    state = prompt;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, prompt);
  }
}

final briefingPromptProvider =
    NotifierProvider<BriefingPromptNotifier, String>(
        BriefingPromptNotifier.new);

// ── 비서 이름 상태 관리 ──────────────────────────────
// 기본값 "키보야" — 사용자가 자유롭게 변경 가능
// 브리핑 문체, 알림 텍스트, 입력 힌트 등에 반영
class AssistantNameNotifier extends Notifier<String> {
  static const _key = 'kibo_assistant_name';
  static const defaultName = '키보야';

  @override
  String build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key) ?? defaultName;
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    state = trimmed.isEmpty ? defaultName : trimmed;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, state);
  }
}

final assistantNameProvider =
    NotifierProvider<AssistantNameNotifier, String>(
        AssistantNameNotifier.new);

// ── 개인정보 동의 상태 관리 ──────────────────────────
class PrivacyConsentNotifier extends Notifier<Map<String, bool>> {
  static const _prefix = 'kibo_consent_';

  static const consentKeys = [
    'location',       // 위치 정보
    'calendar',       // 캘린더 접근
    'notification',   // 알림 권한
    'data_collection', // 사용 데이터 수집
    'ai_processing',  // AI 분석 동의
  ];

  @override
  Map<String, bool> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return {
      for (final key in consentKeys)
        key: prefs.getBool('$_prefix$key') ?? false,
    };
  }

  Future<void> setConsent(String key, bool value) async {
    state = {...state, key: value};
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_prefix$key', value);
  }

  Future<void> acceptAll() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final updated = <String, bool>{};
    for (final key in consentKeys) {
      updated[key] = true;
      await prefs.setBool('$_prefix$key', true);
    }
    state = updated;
  }

  bool get allAccepted => state.values.every((v) => v);
}

final privacyConsentProvider =
    NotifierProvider<PrivacyConsentNotifier, Map<String, bool>>(
        PrivacyConsentNotifier.new);
