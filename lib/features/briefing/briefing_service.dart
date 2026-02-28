// =====================================================
// 📁 lib/features/briefing/briefing_service.dart
// =====================================================

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants.dart';
import '../calendar/schedule_model.dart';

enum BriefingPeriod { morning, afternoon, evening }

extension BriefingPeriodInfo on BriefingPeriod {
  String get label {
    switch (this) {
      case BriefingPeriod.morning:   return '아침';
      case BriefingPeriod.afternoon: return '점심';
      case BriefingPeriod.evening:   return '저녁';
    }
  }

  String get emoji {
    switch (this) {
      case BriefingPeriod.morning:   return '🌅';
      case BriefingPeriod.afternoon: return '☀️';
      case BriefingPeriod.evening:   return '🌙';
    }
  }

  String get focus {
    switch (this) {
      case BriefingPeriod.morning:
        return '오늘 하루 일정을 안내하고, 중요한 일정 준비사항을 먼저 알려줘.';
      case BriefingPeriod.afternoon:
        return '오전이 어떻게 지나갔는지 돌아보고, 남은 오후 일정에 집중해줘.';
      case BriefingPeriod.evening:
        return '오늘 마무리와 내일 일정을 중심으로 안내해줘.';
    }
  }
}

BriefingPeriod detectPeriod() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12)  return BriefingPeriod.morning;
  if (hour >= 12 && hour < 18) return BriefingPeriod.afternoon;
  return BriefingPeriod.evening;
}

class BriefingService {
  final GenerativeModel _model = GenerativeModel(
    model: AppConstants.geminiFlashModel,
    apiKey: AppConstants.geminiApiKey,
  );

  Future<String> generateBriefing(
    List<Schedule> schedules, {
    String userPrompt = '',
  }) async {
    final today = DateTime.now();
    final todayStr = '${today.year}년 ${today.month}월 ${today.day}일';
    final period = detectPeriod();
    final todayStart = DateTime(today.year, today.month, today.day);

    final rangeStart = DateTime(today.year, today.month, today.day - 7);
    final rangeEnd =
        DateTime(today.year, today.month, today.day + 7, 23, 59, 59);

    final rangeSchedules = schedules.where((s) {
      return !s.dateTime.isBefore(rangeStart) &&
          !s.dateTime.isAfter(rangeEnd);
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // ✅ 일정 없고 커스텀 프롬프트도 없으면 바로 반환
    if (rangeSchedules.isEmpty && userPrompt.trim().isEmpty) {
      return '${period.emoji} 앞으로 7일간 예정된 일정이 없어요. 여유롭게 계획해보세요! 😊';
    }

    // ✅ scheduleText 한 번만 선언
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final scheduleText = rangeSchedules.isEmpty
        ? '(현재 등록된 일정 없음)'
        : rangeSchedules.map((s) {
            final dateStr =
                '${s.dateTime.month}/${s.dateTime.day}'
                '(${weekdays[s.dateTime.weekday - 1]})';
            final timeStr =
                '${s.dateTime.hour.toString().padLeft(2, '0')}:'
                '${s.dateTime.minute.toString().padLeft(2, '0')}';
            final locationStr =
                s.location.isNotEmpty ? ' (${s.location})' : '';
            final tag = s.dateTime.isBefore(todayStart)
                ? '[지난 일정]'
                : (s.dateTime.year == today.year &&
                        s.dateTime.month == today.month &&
                        s.dateTime.day == today.day
                    ? '[오늘]'
                    : '');
            return '- $dateStr $timeStr ${s.title}$locationStr $tag';
          }).join('\n');

    final customSection = userPrompt.trim().isNotEmpty
        ? '\n사용자 추가 요청사항 (반드시 반영):\n$userPrompt\n'
        : '';

    final prompt = '''
오늘 날짜: $todayStr
현재 시간대: ${period.label} ${period.emoji}

지난 7일 ~ 앞으로 7일 일정 목록:
$scheduleText
$customSection
위 일정을 바탕으로 ${period.label} 브리핑을 3~4문장으로 작성해줘.

시간대 포커스: ${period.focus}

규칙:
1. 오늘 일정을 가장 먼저 언급해
2. 마감일이나 중요 일정이 며칠 남았는지 상기시켜줘
3. 이전 7일에서 이후 7일 사이의 일정을 분석하여 연속된 일정이라면 언급해줘
4. 숫자를 언급할 때에는 구체적인 날짜가 있는 경우에만 언급할 것
5. 이전 7일, 이후 7일 간 특별한 일정이 없는 경우 "앞으로 7일간"과 같은 언급을 하지않고 자연스러운 문장으로 안내해줘
6. 앞으로 중요한 일정이 있으면 미리 준비하도록 자연스럽게 안내해줘
7. 이모지를 적절히 사용해
8. 반드시 한국어로만 답해
9. 브리핑의 주어는 항상 "사용자"야. AI인 네가 함께 가거나 준비하는 표현은 절대 사용하지 마
예시: "오늘 오후 3시에 강남역 미팅이 있으세요!" (O)
예시: "함께 잘 준비해서 다녀오겠습니다!" (X)
''';

    try {
      final response =
          await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '브리핑을 생성하지 못했어요.';
    } catch (e) {
      debugPrint('브리핑 오류: $e');
      return '브리핑을 생성하지 못했어요.';
    }
  }
}