// =====================================================
// 📁 lib/features/briefing/briefing_service.dart
// =====================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../calendar/schedule_model.dart';
import '../calendar/gemini_service.dart';

class BriefingService {
  final GeminiService _gemini;

  // ✅ SharedPreferences 싱글턴 — 중복 호출 방지
  SharedPreferences? _prefs;

  BriefingService({GeminiService? gemini})
      : _gemini = gemini ?? GeminiService();

  // ── SharedPreferences 초기화 (최초 1회) ───────────
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── 오늘 날짜 기반 캐시 키 ────────────────────────
  static String _dateKey() {
    final now = DateTime.now();
    return 'briefing_${now.year}_${now.month}_${now.day}';
  }

  // ✅ 일정 상태 해시 — 일정 추가/삭제 감지용
  // 오늘 일정 ID + 제목 + 시간 조합으로 해시 생성
  static String _scheduleHash(List<Schedule> todaySchedules) {
    final combined = todaySchedules
        .map((s) => '${s.id}_${s.title}_${s.dateTime.millisecondsSinceEpoch}')
        .join('|');
    var hash = 0;
    for (final c in combined.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash.toString();
  }

  // ── 오늘 일정만 필터링 ────────────────────────────
  List<Schedule> _todaySchedules(List<Schedule> all) {
    final now = DateTime.now();
    return all
        .where((s) =>
            s.dateTime.year == now.year &&
            s.dateTime.month == now.month &&
            s.dateTime.day == now.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ── Schedule → Map 변환 ───────────────────────────
  List<Map<String, dynamic>> _toMapList(List<Schedule> schedules) {
    return schedules
        .map((s) => {
              'title': s.title,
              'time': '${s.dateTime.hour.toString().padLeft(2, '0')}:'
                  '${s.dateTime.minute.toString().padLeft(2, '0')}',
              'location': s.location,
              'tags': s.tags,
              'companions': s.companions,
              'transportMode': s.transportMode.name,
              'importance': s.importance,
            })
        .toList();
  }

  // ── ✅ 브리핑 생성 ─────────────────────────────────
  // weather: 외부에서 동적으로 주입 (하드코딩 제거)
  Future<String> generateBriefing(
    List<Schedule> allSchedules, {
    String userPrompt = '',
    bool forceRefresh = false,
    // ✅ 날씨 데이터 외부 주입 — 기본값은 null (없으면 생략)
    Map<String, dynamic>? weather,
  }) async {
    final prefs = await _getPrefs();
    final dateKey = _dateKey();
    final todaySchedules = _todaySchedules(allSchedules);

    // ✅ 스마트 캐시 무효화
    // 날짜 + 일정 상태 해시 조합으로 캐시 유효성 판단
    final currentHash = _scheduleHash(todaySchedules);
    final savedHash = prefs.getString('${dateKey}_hash');
    final cachedBriefing = prefs.getString(dateKey);

    final isCacheValid = !forceRefresh &&
        cachedBriefing != null &&
        cachedBriefing.isNotEmpty &&
        savedHash == currentHash;

    if (isCacheValid) {
      debugPrint('브리핑 캐시 사용 (해시 일치): $currentHash');
      return cachedBriefing!;
    }

    debugPrint('브리핑 재생성 (해시 변경: $savedHash → $currentHash)');

    // 오늘 일정 없음
    if (todaySchedules.isEmpty) {
      const empty = '오늘은 등록된 일정이 없어요. 여유로운 하루 보내세요 😊';
      await _saveCache(prefs, dateKey, empty, currentHash);
      return empty;
    }

    // ✅ 날씨 — 외부 주입값 우선, 없으면 기본 안내
    final weatherData = weather ??
        {'description': '날씨 정보 없음', 'temp': ''};

    try {
      final result = await _gemini.generateBriefing(
        schedules: _toMapList(todaySchedules),
        weather: weatherData,
        customPrompt: userPrompt,
      );

      final briefing = result ?? _fallbackBriefing(todaySchedules);
      await _saveCache(prefs, dateKey, briefing, currentHash);
      debugPrint('브리핑 생성 완료 (${todaySchedules.length}개 일정)');
      return briefing;
    } catch (e) {
      debugPrint('브리핑 생성 오류: $e');
      final fallback = _fallbackBriefing(todaySchedules);
      await _saveCache(prefs, dateKey, fallback, currentHash);
      return fallback;
    }
  }

  // ── 캐시 저장 (브리핑 + 해시 함께) ──────────────
  Future<void> _saveCache(
    SharedPreferences prefs,
    String dateKey,
    String briefing,
    String hash,
  ) async {
    await prefs.setString(dateKey, briefing);
    await prefs.setString('${dateKey}_hash', hash);
  }

  // ── Gemini 실패 시 기본 브리핑 ────────────────────
  String _fallbackBriefing(List<Schedule> schedules) {
    if (schedules.isEmpty) return '오늘은 등록된 일정이 없어요 😊';

    final first = schedules.first;
    final h = first.dateTime.hour.toString().padLeft(2, '0');
    final m = first.dateTime.minute.toString().padLeft(2, '0');
    final count = schedules.length;
    final emoji = first.tags.isNotEmpty
        ? GeminiService.emojiForTag(first.tags.first)
        : '📌';

    if (count == 1) {
      return '$emoji 오늘 $h:$m에 ${first.title} 일정이 있어요. 좋은 하루 되세요!';
    }
    return '$emoji 오늘 일정이 ${count}개 있어요. '
        '첫 번째는 $h:$m ${first.title}이에요. 알차게 하루 보내세요!';
  }

  // ── 캐시 삭제 ─────────────────────────────────────
  Future<void> clearCache() async {
    final prefs = await _getPrefs();
    final key = _dateKey();
    await prefs.remove(key);
    await prefs.remove('${key}_hash');
    debugPrint('브리핑 캐시 삭제');
  }

  // ── 오늘 일정 요약 텍스트 ─────────────────────────
  String todaySummary(List<Schedule> allSchedules) {
    final today = _todaySchedules(allSchedules);
    if (today.isEmpty) return '오늘 일정 없음';
    if (today.length == 1) {
      final s = today.first;
      final h = s.dateTime.hour.toString().padLeft(2, '0');
      final m = s.dateTime.minute.toString().padLeft(2, '0');
      return '$h:$m ${s.title}';
    }
    return '일정 ${today.length}개';
  }
}