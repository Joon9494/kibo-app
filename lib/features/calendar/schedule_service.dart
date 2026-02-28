// =====================================================
// 📁 lib/features/calendar/schedule_service.dart
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'schedule_model.dart';
import 'google_calendar_service.dart';
import '../map/tmap_service.dart';
import '../map/location_service.dart';
import '../notification/notification_service.dart';

class ScheduleService {
  final FirebaseFirestore _db;
  final GoogleCalendarService _calendarService;
  final TmapService _tmapService;
  final LocationService _locationService;
  final NotificationService _notificationService;

  ScheduleService({
    FirebaseFirestore? db,
    GoogleCalendarService? calendarService,
    TmapService? tmapService,
    LocationService? locationService,
    NotificationService? notificationService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _calendarService = calendarService ?? GoogleCalendarService(),
        _tmapService = tmapService ?? TmapService(),
        _locationService = locationService ?? LocationService(),
        _notificationService = notificationService ?? NotificationService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DateTime? _parseDateTime(String dateStr, String timeStr) {
    try {
      final combined = '${dateStr}T$timeStr';
      final dt = DateTime.tryParse(combined);
      if (dt != null) return dt.toLocal();
      final fmt = DateFormat("yyyy-MM-dd'T'HH:mm");
      return fmt.parseLoose(combined).toLocal();
    } catch (e) {
      debugPrint('DateTime 파싱 오류: $e');
      return null;
    }
  }

  // ── 일정 저장 ──────────────────────────────────────
  Future<bool> saveSchedule(Map<String, dynamic> parsed) async {
    if (_uid == null) return false;

    try {
      final dateStr = parsed['date']?.toString() ?? '';
      final timeStr = parsed['time']?.toString() ?? '09:00';

      final dateTime = _parseDateTime(dateStr, timeStr);
      if (dateTime == null) {
        debugPrint('날짜 파싱 오류: date=$dateStr, time=$timeStr');
        return false;
      }

      final tags = List<String>.from(parsed['tags'] ?? []);
      final transportMode = TransportMode.values.firstWhere(
        (e) => e.name == (parsed['transportMode'] ?? 'unknown'),
        orElse: () => TransportMode.unknown,
      );

      final schedule = Schedule(
        id: '',
        title: parsed['title']?.toString() ?? '새 일정',
        dateTime: dateTime,
        location: parsed['location']?.toString() ?? '',
        description: parsed['description']?.toString() ?? '',
        uid: _uid!,
        tags: tags,
        transportMode: transportMode,
        companions: parsed['companions']?.toString() ?? '',
      );

      // 1단계: Google 캘린더 등록
      String googleEventId = '';
      bool googleSyncSuccess = false;
      try {
        final eventId = await _calendarService.addEvent(
          title: schedule.title,
          dateTime: schedule.dateTime,
          location: schedule.location,
          description: schedule.description,
          tags: tags,
        );
        googleEventId = eventId ?? '';
        googleSyncSuccess = googleEventId.isNotEmpty;
      } catch (e) {
        debugPrint('Google 캘린더 동기화 오류: $e');
      }

      final scheduleWithGoogle =
          schedule.copyWith(googleEventId: googleEventId);

      // 2단계: Firestore 저장
      String firestoreId = '';
      try {
        final docRef = await _db
            .collection('schedules')
            .doc(_uid)
            .collection('items')
            .add(scheduleWithGoogle.toMap());
        firestoreId = docRef.id;
      } catch (e) {
        debugPrint('Firestore 저장 오류: $e');
        if (googleSyncSuccess && googleEventId.isNotEmpty) {
          await _safeRollbackGoogleEvent(googleEventId);
        }
        return false;
      }

      // 3단계: 장소 있고 미래 일정이면 자동 알람
      if (schedule.location.isNotEmpty &&
          schedule.dateTime.isAfter(DateTime.now())) {
        _scheduleTransportAlarmIfPossible(
          firestoreId: firestoreId,
          schedule: schedule,
        );
      }

      return true;
    } catch (e) {
      debugPrint('일정 저장 오류: $e');
      return false;
    }
  }

  // ── Google 캘린더 롤백 ─────────────────────────────
  Future<void> _safeRollbackGoogleEvent(String googleEventId) async {
    try {
      await _calendarService.deleteEvent(googleEventId);
      debugPrint('롤백 완료: $googleEventId');
    } catch (e) {
      debugPrint('롤백 실패: $e');
      try {
        await _db.collection('orphan_events').add({
          'googleEventId': googleEventId,
          'uid': _uid,
          'createdAt': DateTime.now(),
          'reason': 'firestore_save_failed',
        });
      } catch (recordError) {
        debugPrint('고아 객체 기록 실패: $recordError');
      }
    }
  }

  // ── 교통 예측 알람 설정 ────────────────────────────
  Future<void> _scheduleTransportAlarmIfPossible({
    required String firestoreId,
    required Schedule schedule,
  }) async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        debugPrint('위치 정보 없음 → 알람 설정 건너뜀');
        return;
      }

      final places = await _tmapService.searchPlace(schedule.location);
      if (places.isEmpty) {
        debugPrint('장소 검색 실패 → 알람 설정 건너뜀');
        return;
      }

      final routeMinutes = await _tmapService.getRouteMinutes(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: places.first.lat,
        endLng: places.first.lng,
      );
      if (routeMinutes == null) {
        debugPrint('경로 계산 실패 → 알람 설정 건너뜀');
        return;
      }

      debugPrint('소요시간: $routeMinutes분 → 자동 알람 설정');

      await _notificationService.scheduleAutoAlarm(
        schedule: schedule.copyWith(id: firestoreId),
        routeMinutes: routeMinutes,
      );
    } catch (e) {
      debugPrint('교통 예측 알람 오류: $e');
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

  // ── 일정 삭제 ──────────────────────────────────────
  Future<bool> deleteSchedule(Schedule schedule) async {
    if (_uid == null) return false;
    try {
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('items')
          .doc(schedule.id)
          .delete();

      if (schedule.googleEventId.isNotEmpty) {
        try {
          await _calendarService.deleteEvent(schedule.googleEventId);
        } catch (e) {
          debugPrint('Google 캘린더 삭제 오류: $e');
        }
      }

      // ✅ 관련 알람도 함께 취소
      await _notificationService.cancelScheduleAlarms(schedule.id);

      return true;
    } catch (e) {
      debugPrint('일정 삭제 오류: $e');
      return false;
    }
  }
}