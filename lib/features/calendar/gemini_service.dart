// =====================================================
// 📁 lib/features/calendar/gemini_service.dart
// =====================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import 'schedule_model.dart';

// ── 대화형 파싱 결과 ──────────────────────────────────
class ParseResult {
  final Map<String, dynamic> data;
  final List<FollowUpQuestion> questions;
  final bool isComplete;

  const ParseResult({
    required this.data,
    required this.questions,
    required this.isComplete,
  });
}

// ── 추가 질문 항목 ────────────────────────────────────
class FollowUpQuestion {
  final String field;
  final String label;
  final List<String> options;
  final bool skippable;

  const FollowUpQuestion({
    required this.field,
    required this.label,
    required this.options,
    this.skippable = true,
  });
}

class GeminiService {
  // ✅ responseMimeType으로 JSON 강제
  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  // ── 태그별 이모티콘 ───────────────────────────────
  static const Map<String, String> _tagEmojis = {
    '업무': '💼',
    '개인': '🙂',
    '의료': '🏥',
    '여행': '✈️',
    '쇼핑': '🛍️',
    '가족': '🏠',
    '기타': '📌',
  };

  static String emojiForTag(String tag) =>
      _tagEmojis[tag] ?? '📌';

  static String addEmoji(String title, List<String> tags) {
    if (tags.isEmpty) return '📌 $title';
    final emoji = emojiForTag(tags.first);
    if (title.startsWith(emoji)) return title;
    return '$emoji $title';
  }

  // ✅ Dart에서 날짜 계산 후 주입 — LLM 환각 방지
  Map<String, String> _buildDateContext() {
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return {
      'today': fmt(now),
      'tomorrow': fmt(now.add(const Duration(days: 1))),
      'dayAfterTomorrow': fmt(now.add(const Duration(days: 2))),
      'nextMonday': fmt(_nextWeekday(now, DateTime.monday)),
      'nextTuesday': fmt(_nextWeekday(now, DateTime.tuesday)),
      'nextWednesday': fmt(_nextWeekday(now, DateTime.wednesday)),
      'nextThursday': fmt(_nextWeekday(now, DateTime.thursday)),
      'nextFriday': fmt(_nextWeekday(now, DateTime.friday)),
      'nextSaturday': fmt(_nextWeekday(now, DateTime.saturday)),
      'nextSunday': fmt(_nextWeekday(now, DateTime.sunday)),
    };
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    int daysUntil = weekday - from.weekday;
    if (daysUntil <= 0) daysUntil += 7;
    return from.add(Duration(days: daysUntil));
  }

  // ── 자연어 → 일정 파싱 + 추가 질문 생성 ──────────
  Future<ParseResult?> parseScheduleWithFollowUp(String input) async {
    final dates = _buildDateContext();

    final prompt = '''
아래 날짜 기준으로 일정을 파싱해줘.

=== 정확한 날짜 참조 (이 값을 그대로 사용할 것) ===
오늘: ${dates['today']}
내일: ${dates['tomorrow']}
모레: ${dates['dayAfterTomorrow']}
다음주 월요일: ${dates['nextMonday']}
다음주 화요일: ${dates['nextTuesday']}
다음주 수요일: ${dates['nextWednesday']}
다음주 목요일: ${dates['nextThursday']}
다음주 금요일: ${dates['nextFriday']}
다음주 토요일: ${dates['nextSaturday']}
다음주 일요일: ${dates['nextSunday']}

입력: "$input"

다음 JSON 구조로 반환해:
{
  "title": "순수 제목 (이모티콘 없이)",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "location": "장소 (없으면 빈 문자열)",
  "description": "추가 설명 (없으면 빈 문자열)",
  "tags": ["태그명"],
  "companions": "혼자/가족/친구/동료 (추론 불가면 빈 문자열)",
  "transportMode": "car/transit/walk/bicycle (추론 불가면 빈 문자열)",
  "importance": "high/normal/low",
  "missing": ["추론하지 못한 필드명 목록"]
}

규칙:
- 날짜 없으면 오늘(${dates['today']}) 사용
- 시간 없으면 09:00
- 오후 3시 = 15:00
- 태그 추론: 미팅/회의/업무 → 업무, 병원/진료 → 의료, 여행/출장 → 여행, 쇼핑/마트 → 쇼핑, 가족/부모님 → 가족, 그 외 → 개인
- 추론 못한 필드는 missing 배열에 포함
''';

    try {
      // ✅ timeout 10초
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Gemini 응답 시간 초과 (10초)'),
          );

      final text = response.text;
      if (text == null) return null;

      // ✅ responseMimeType 적용으로 replaceAll 불필요
      // 혹시 모를 경우를 위한 최소한의 정리만 유지
      final cleaned = text.trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final missing = List<String>.from(data['missing'] ?? []);

      // ── 추가 질문 생성 ────────────────────────────
      final questions = <FollowUpQuestion>[];

      if (missing.contains('transportMode')) {
        questions.add(const FollowUpQuestion(
          field: 'transportMode',
          label: '🚗 어떻게 이동하실 건가요?',
          options: ['자동차', '대중교통', '도보', '자전거'],
        ));
      }

      if (missing.contains('companions')) {
        questions.add(const FollowUpQuestion(
          field: 'companions',
          label: '👥 누구와 함께 가시나요?',
          options: ['혼자', '가족', '친구', '동료'],
        ));
      }

      if (missing.contains('tags')) {
        questions.add(const FollowUpQuestion(
          field: 'tags',
          label: '📂 어떤 종류의 일정인가요?',
          options: ['업무', '개인', '의료', '여행', '쇼핑', '가족'],
        ));
      }

      data.remove('missing');

      return ParseResult(
        data: data,
        questions: questions,
        isComplete: questions.isEmpty,
      );
    } on FormatException catch (e) {
      debugPrint('Gemini JSON 파싱 오류: $e');
      return null;
    } catch (e) {
      debugPrint('Gemini 파싱 오류: $e');
      return null;
    }
  }

  // ── 기존 호환용 parseSchedule ─────────────────────
  Future<Map<String, dynamic>?> parseSchedule(String input) async {
    final result = await parseScheduleWithFollowUp(input);
    return result?.data;
  }

  // ── 브리핑 생성 ───────────────────────────────────
  Future<String?> generateBriefing({
    required List<Map<String, dynamic>> schedules,
    required Map<String, dynamic> weather,
    String customPrompt = '',
  }) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}년 ${today.month}월 ${today.day}일';

    final hasFamily = schedules.any((s) =>
        (s['companions'] ?? '').contains('가족') ||
        (s['tags'] as List? ?? []).contains('가족'));
    final hasWork = schedules.any((s) =>
        (s['tags'] as List? ?? []).contains('업무'));
    final hasMedical = schedules.any((s) =>
        (s['tags'] as List? ?? []).contains('의료'));

    String toneGuide = '';
    if (hasFamily) toneGuide += '가족 일정이 있으니 따뜻하고 친근한 톤으로. ';
    if (hasWork) toneGuide += '업무 일정이 있으니 전문적이고 명확하게. ';
    if (hasMedical) toneGuide += '의료 일정이 있으니 건강 관련 한마디 포함. ';

    final prompt = '''
오늘은 $todayStr입니다.

오늘의 일정:
${schedules.map((s) {
      final tags = (s['tags'] as List? ?? []).join(', ');
      final companions = s['companions'] ?? '혼자';
      final transport = s['transportMode'] ?? '';
      return '- ${s['time']} ${s['title']} '
          '${s['location']?.isNotEmpty == true ? '(${s['location']})' : ''} '
          '${tags.isNotEmpty ? '#$tags' : ''} '
          '${companions != '혼자' ? '동행: $companions' : ''} '
          '${transport.isNotEmpty ? '이동: $transport' : ''}';
    }).join('\n')}

날씨: ${weather['description'] ?? '정보 없음'}, ${weather['temp'] ?? ''}도
톤 가이드: $toneGuide
${customPrompt.isNotEmpty ? '추가 요청: $customPrompt' : ''}

위 정보를 바탕으로 오늘 하루 브리핑을 2~4문장으로 작성해줘.
친근하고 자연스럽게, 오늘 일정과 날씨를 포함해서.
''';

    try {
      // ✅ timeout 15초 (브리핑은 좀 더 여유)
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('브리핑 생성 시간 초과 (15초)'),
          );
      return response.text;
    } catch (e) {
      debugPrint('브리핑 생성 오류: $e');
      return null;
    }
  }
}