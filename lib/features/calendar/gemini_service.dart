// =====================================================
// 📁 lib/features/calendar/gemini_service.dart
// 역할: 자연어 문장을 Gemini AI가 일정 데이터로 변환
//       예: "내일 오후 3시 강남역 미팅"
//        → { title: "미팅", date: "2026-02-23", time: "15:00", location: "강남역" }
// =====================================================

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';

class GeminiService {
  // Gemini Flash 모델 사용 — 빠르고 저렴함
  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
  );

  // ── 자연어 → 일정 데이터 변환 ─────────────────────
  // 입력: "내일 오후 3시 강남역 미팅"
  // 출력: Map { title, date, time, location, description }
  Future<Map<String, dynamic>?> parseSchedule(String input) async {
    // 오늘 날짜를 프롬프트에 포함 (내일, 다음주 등 상대적 날짜 계산용)
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Gemini에게 보낼 프롬프트
    // JSON만 반환하도록 명확히 지시
    final prompt = '''
오늘 날짜: $todayStr

다음 문장을 일정 데이터로 변환해줘. 반드시 JSON 형식으로만 답해. 다른 말은 하지 마.

입력: "$input"

출력 형식:
{
  "title": "일정 제목",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "location": "장소 (없으면 빈 문자열)",
  "description": "추가 설명 (없으면 빈 문자열)"
}

규칙:
- 날짜가 없으면 오늘 날짜 사용
- 시간이 없으면 "09:00" 사용
- 오전/오후를 24시간으로 변환 (오후 3시 = 15:00)
- "내일" = 오늘 + 1일
- "다음주 월요일" 등 상대적 날짜도 계산
''';

    try {
      // Gemini API 호출
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text;
      if (text == null) return null;

      // JSON 파싱 — Gemini가 ```json ``` 으로 감쌀 수 있어서 제거
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      print('Gemini 오류: $e');
      return null;
    }
  }
}