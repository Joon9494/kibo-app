import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../calendar/schedule_model.dart';
import 'package:flutter/foundation.dart';

class BriefingService {
  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
  );

  Future<String> generateBriefing(List<Schedule> schedules) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}년 ${today.month}월 ${today.day}일';

    // 오늘 일정만 필터링
    final todaySchedules = schedules.where((s) {
      return s.dateTime.year == today.year &&
          s.dateTime.month == today.month &&
          s.dateTime.day == today.day;
    }).toList();

    // 일정 없으면 Gemini 호출 없이 바로 반환
    if (todaySchedules.isEmpty) {
      return '오늘은 예정된 일정이 없어요. 여유로운 하루 보내세요! 😊';
    }

    // 일정 목록을 텍스트로 변환
    final scheduleText = todaySchedules.map((s) {
      final timeStr =
          '${s.dateTime.hour.toString().padLeft(2, '0')}:${s.dateTime.minute.toString().padLeft(2, '0')}';
      final locationStr = s.location.isNotEmpty ? ' (${s.location})' : '';
      return '- $timeStr ${s.title}$locationStr';
    }).join('\n');

    final prompt = '''
오늘 날짜: $todayStr
오늘의 일정 목록:
$scheduleText

위 일정을 바탕으로 자연스럽고 친근한 하루 브리핑을 2~3문장으로 작성해줘.
시간 순서대로 언급하고, 이모지를 적절히 사용해.
반드시 한국어로만 답해.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '브리핑을 생성하지 못했어요.';
    } catch (e) {
      debugPrint('브리핑 오류: $e');
      return '브리핑을 생성하지 못했어요.';
    }
  }
}