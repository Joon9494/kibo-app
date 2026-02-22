// =====================================================
// 📁 lib/features/calendar/schedule_service.dart
// 역할: Firestore에 일정을 저장하고 불러오는 파일
//       GeminiService가 파싱한 데이터를 받아서 저장
//       사용자별로 일정을 분리해서 관리 (uid 기준)
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'schedule_model.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 현재 로그인된 사용자 uid
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── 일정 저장 ──────────────────────────────────────
  // Gemini가 파싱한 Map 데이터를 받아서 Firestore에 저장
  Future<bool> saveSchedule(Map<String, dynamic> parsed) async {
    if (_uid == null) return false;

    try {
      // 날짜 + 시간 문자열 → DateTime 변환
      // parsed['date'] = "2026-02-23"
      // parsed['time'] = "15:00"
      final dateStr = parsed['date'] as String;
      final timeStr = parsed['time'] as String;
      final dateTimeParts = timeStr.split(':');

      final dateTime = DateTime(
        int.parse(dateStr.split('-')[0]), // 년
        int.parse(dateStr.split('-')[1]), // 월
        int.parse(dateStr.split('-')[2]), // 일
        int.parse(dateTimeParts[0]),      // 시
        int.parse(dateTimeParts[1]),      // 분
      );

      // Schedule 객체 생성
      final schedule = Schedule(
        id: '',  // Firestore가 자동 생성
        title: parsed['title'] ?? '새 일정',
        dateTime: dateTime,
        location: parsed['location'] ?? '',
        description: parsed['description'] ?? '',
        uid: _uid!,
      );

      // Firestore에 저장
      // schedules/{uid}/items/{자동ID} 구조로 저장
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('items')
          .add(schedule.toMap());

      return true;
    } catch (e) {
      return false;
    }
  }

  // ── 일정 목록 실시간 조회 ──────────────────────────
  // Stream = 데이터가 바뀔 때마다 자동으로 화면 갱신
  Stream<List<Schedule>> getSchedules() {
    if (_uid == null) return const Stream.empty();

    return _db
        .collection('schedules')
        .doc(_uid)
        .collection('items')
        .orderBy('dateTime')  // 날짜순 정렬
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Schedule.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ── 일정 삭제 ──────────────────────────────────────
  Future<bool> deleteSchedule(String scheduleId) async {
    if (_uid == null) return false;
    try {
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('items')
          .doc(scheduleId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}