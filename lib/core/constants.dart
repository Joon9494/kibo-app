// =====================================================
// 📁 lib/core/constants.dart
// 역할: 앱 전체에서 사용하는 상수값 모음
//       모델명 변경 시 여기만 수정하면 앱 전체 반영
// =====================================================

class AppConstants {
  // Gemini API 키
  static const String geminiApiKey = 'AIzaSyAiGPdZDhJ9nnGf3DIwgqwXDAg7BXmXnAw';

  // Gemini 모델명 — 업데이트 시 여기만 수정
  static const String geminiFlashModel = 'gemini-2.0-flash'; // 빠른 처리 (일정 파싱, 요약)
  static const String geminiProModel = 'gemini-2.0-pro-exp'; // 심층 처리 (브리핑 통합)
}