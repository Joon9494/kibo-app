// =====================================================
// 📁 lib/core/constants.dart
// 역할: 앱 전체에서 사용하는 상수값 모음
//       모든 변경은 여기서 설정하면 앱 전체 반영
// =====================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Gemini API 키 — .env 파일에서 로드
  static String get geminiApiKey =>
      dotenv.env['GEMINI_API_KEY'] ?? '';

  // Gemini 모델명 — 업데이트 시 여기서 설정
  static const String geminiFlashModel = 'gemini-2.5-flash';
  static const String geminiProModel = 'gemini-2.5-flash';
  static String get tmapApiKey =>
    dotenv.env['TMAP_API_KEY'] ?? '';
}