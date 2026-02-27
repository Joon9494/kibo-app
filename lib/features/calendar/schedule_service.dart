// =====================================================
// 📁 lib/features/calendar/schedule_service.dart
// 역할: Firestore에 일정을 저장하고 불러오는 파일
//       GeminiService가 파싱한 데이터를 받아서 저장
//       사용자별로 일정을 분리해서 관리 (uid 기준)
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'schedule_model.dart';
import 'google_calendar_service.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleCalendarService _calendarService = GoogleCalendarService();

  // 현재 로그인된 사용자 uid
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── 일정 저장 ──────────────────────────────────────
  Future<bool> saveSchedule(Map<String, dynamic> parsed) async {
    if (_uid == null) return false;

    try {
      // 안전한 날짜 파싱 — DateTime.tryParse 활용
      final dateStr = parsed['date']?.toString() ?? '';
      final timeStr = parsed['time']?.toString() ?? '09:00';
      final combined = '${dateStr}T${timeStr}:00';
      final dateTime = DateTime.tryParse(combined);

      if (dateTime == null) {
        debugPrint('날짜 파싱 오류: date=$dateStr, time=$timeStr');
        return false;
      }

      // Schedule 객체 생성
      final schedule = Schedule(
        id: '',
        title: parsed['title']?.toString() ?? '새 일정',
        dateTime: dateTime,
        location: parsed['location']?.toString() ?? '',
        description: parsed['description']?.toString() ?? '',
        uid: _uid!,
      );

      // 1단계: Google 캘린더에 먼저 등록 후 이벤트 ID 획득
      String googleEventId = '';
      try {
        final eventId = await _calendarService.addEvent(
          title: schedule.title,
          dateTime: schedule.dateTime,
          location: schedule.location,
          description: schedule.description,
        );
        googleEventId = eventId ?? '';
      } catch (e) {
        debugPrint('Google 캘린더 동기화 오류: $e');
      }

      // 2단계: copyWith로 googleEventId 포함한 완전한 객체 생성
      final scheduleWithId = schedule.copyWith(googleEventId: googleEventId);

      // 3단계: Firestore 저장
      try {
        await _db
            .collection('schedules')
            .doc(_uid)
            .collection('items')
            .add(scheduleWithId.toMap());
      } catch (e) {
        // Firestore 저장 실패 시 Google 캘린더 이벤트 롤백
        debugPrint('Firestore 저장 오류: $e');
        if (googleEventId.isNotEmpty) {
          try {
            await _calendarService.deleteEvent(googleEventId);
            debugPrint('롤백 완료: Google 캘린더 이벤트 삭제');
          } catch (rollbackError) {
            debugPrint('롤백 실패: $rollbackError');
          }
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('일정 저장 오류: $e');
      return false;
    }
  }

  // ── 일정 목록 실시간 조회 ──────────────────────────
  Stream<List<Schedule>> getSchedules() {
    if (_uid == null) return const Stream.empty();

    return _db
        .collection('schedules')
        .doc(_uid)
        .collection('items')
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Schedule.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ── 일정 삭제 — Schedule 객체 전체를 받아 내부에서 처리 ──
  Future<bool> deleteSchedule(Schedule schedule) async {
    if (_uid == null) return false;
    try {
      // Firestore 삭제
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('items')
          .doc(schedule.id)
          .delete();

      // Google 캘린더 이벤트도 함께 삭제
      if (schedule.googleEventId.isNotEmpty) {
        try {
          await _calendarService.deleteEvent(schedule.googleEventId);
        } catch (e) {
          debugPrint('Google 캘린더 삭제 오류: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('일정 삭제 오류: $e');
      return false;
    }
  }
}