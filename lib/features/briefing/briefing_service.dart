import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../calendar/schedule_model.dart';

class BriefingService {
  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
  );

  Future<String> generateBriefing(List<Schedule> schedules) async {
    final today = DateTime.now();
    final todayStr = '${today.year}년 ${today.month}월 ${today.day}일';

    // 오늘 자정 기준
    final todayStart = DateTime(today.year, today.month, today.day);

    // -7일 ~ +7일 경계값 포함 필터링
    final rangeStart = DateTime(today.year, today.month, today.day - 7);
    final rangeEnd = DateTime(today.year, today.month, today.day + 7, 23, 59, 59);

    final rangeSchedules = schedules.where((s) {
      return !s.dateTime.isBefore(rangeStart) &&
          !s.dateTime.isAfter(rangeEnd);
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 범위 내 일정 없으면 Gemini 호출 없이 반환
    if (rangeSchedules.isEmpty) {
      return '앞으로 7일간 예정된 일정이 없어요. 여유롭게 계획해보세요! 😊';
    }

    // 일정 목록을 텍스트로 변환
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final scheduleText = rangeSchedules.map((s) {
      final dateStr =
          '${s.dateTime.month}/${s.dateTime.day}(${weekdays[s.dateTime.weekday - 1]})';
      final timeStr =
          '${s.dateTime.hour.toString().padLeft(2, '0')}:${s.dateTime.minute.toString().padLeft(2, '0')}';
      final locationStr = s.location.isNotEmpty ? ' (${s.location})' : '';
      final isPast = s.dateTime.isBefore(todayStart) ? '[지난 일정]' : '';
      final isToday = s.dateTime.year == today.year &&
              s.dateTime.month == today.month &&
              s.dateTime.day == today.day
          ? '[오늘]'
          : '';
      return '- $dateStr $timeStr ${s.title}$locationStr $isPast$isToday';
    }).join('\n');

    final prompt = '''
오늘 날짜: $todayStr
지난 7일 ~ 앞으로 7일 일정 목록:
$scheduleText

위 일정을 바탕으로 지능형 브리핑을 3~4문장으로 작성해줘.
아래 규칙을 따라줘:

1. 오늘 일정을 가장 먼저 언급해
2. 마감일이나 중요 일정이 며칠 남았는지 상기시켜줘
3. 이전 7일에서 이후 7일 사이의 일정을 분석하여 연속된 일정이라면 연속되는 일정이 있음을 언급해줘
4. 일정이 없는 경우 '7일' 등의 숫자를 언급하지 않고 자연스러운 문장으로 안내해줘
5. 앞으로 중요한 일정이 있으면 미리 준비하도록 자연스럽게 안내해줘
6. 이모지를 적절히 사용해
7. 반드시 한국어로만 답해
8. 브리핑의 주어는 항상 "사용자"야. AI인 네가 함께 가거나 준비하는 표현은 절대 사용하지 마
예시: "오늘 오후 3시에 강남역 미팅이 있으세요!" (O)
예시: "함께 잘 준비해서 다녀오겠습니다!" (X)
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