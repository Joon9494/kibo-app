// =====================================================
// 📁 lib/features/arrival/arrival_tracking_service.dart
// 역할: 8단계 — 도착 추적 서비스
//       기존 TmapService + LocationService + NotificationService 활용
//       출발 시각 역산, 2차 교통 검증, 이동 중 추적, 도착 감지
// =====================================================

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/tmap_service.dart';
import '../map/location_service.dart';
import '../notification/notification_service.dart';
import '../calendar/schedule_model.dart';

// ──────────────────────────────────────────────
// Riverpod Provider
// ──────────────────────────────────────────────

final arrivalTrackingProvider =
    StateNotifierProvider<ArrivalTrackingNotifier, ArrivalTrackingState>(
  (ref) => ArrivalTrackingNotifier(),
);

// ──────────────────────────────────────────────
// 상태 모델
// ──────────────────────────────────────────────

enum TrackingStatus {
  idle,            // 추적 안 함
  scheduled,       // 출발 알람 설정됨
  preCheck,        // 2차 교통 검증 중
  traveling,       // 이동 중
  nearDestination, // 목적지 근처 (500m)
  arrived,         // 도착 완료
  failed,          // 추적 실패
}

class DepartureInfo {
  final String scheduleId;
  final String scheduleTitle;
  final DateTime eventStartTime;
  final DateTime recommendedDeparture;
  final int estimatedMinutes;     // 예상 이동 시간 (분)
  final int bufferMinutes;        // 여유 시간 (분)
  final String location;          // 목적지 이름
  final double destLat;
  final double destLng;
  final TransportMode transportMode;

  const DepartureInfo({
    required this.scheduleId,
    required this.scheduleTitle,
    required this.eventStartTime,
    required this.recommendedDeparture,
    required this.estimatedMinutes,
    required this.bufferMinutes,
    required this.location,
    required this.destLat,
    required this.destLng,
    required this.transportMode,
  });

  /// "지금 출발하면 N분 여유" or "N분 늦을 수 있어요"
  String get departureMessage {
    final now = DateTime.now();
    final diff = recommendedDeparture.difference(now);

    if (diff.isNegative) {
      final late = diff.abs().inMinutes;
      return '⚠️ 추천 출발 시각이 ${late}분 지났어요!';
    } else if (diff.inMinutes <= 5) {
      return '🔔 지금 출발하면 딱 맞아요!';
    } else {
      return '✅ 출발까지 ${diff.inMinutes}분 여유 있어요.';
    }
  }

  /// 브리핑용 한줄 요약
  String get briefingSummary {
    final emoji = transportMode.emoji;
    final h = recommendedDeparture.hour.toString().padLeft(2, '0');
    final m = recommendedDeparture.minute.toString().padLeft(2, '0');
    return '$emoji ${estimatedMinutes}분 소요 · $h:$m 출발 추천';
  }
}

class ArrivalTrackingState {
  final TrackingStatus status;
  final String? activeScheduleId;
  final DepartureInfo? departureInfo;
  final Position? currentPosition;
  final double? distanceToDestination; // 미터
  final int? latestRouteMinutes;       // 최신 소요시간 (2차 검증)
  final DateTime? actualDepartureTime;
  final DateTime? actualArrivalTime;
  final String? errorMessage;

  // 오늘 전체 출발 알람 목록
  final List<DepartureInfo> todayAlarms;

  const ArrivalTrackingState({
    this.status = TrackingStatus.idle,
    this.activeScheduleId,
    this.departureInfo,
    this.currentPosition,
    this.distanceToDestination,
    this.latestRouteMinutes,
    this.actualDepartureTime,
    this.actualArrivalTime,
    this.errorMessage,
    this.todayAlarms = const [],
  });

  ArrivalTrackingState copyWith({
    TrackingStatus? status,
    String? activeScheduleId,
    DepartureInfo? departureInfo,
    Position? currentPosition,
    double? distanceToDestination,
    int? latestRouteMinutes,
    DateTime? actualDepartureTime,
    DateTime? actualArrivalTime,
    String? errorMessage,
    List<DepartureInfo>? todayAlarms,
  }) {
    return ArrivalTrackingState(
      status: status ?? this.status,
      activeScheduleId: activeScheduleId ?? this.activeScheduleId,
      departureInfo: departureInfo ?? this.departureInfo,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceToDestination:
          distanceToDestination ?? this.distanceToDestination,
      latestRouteMinutes: latestRouteMinutes ?? this.latestRouteMinutes,
      actualDepartureTime:
          actualDepartureTime ?? this.actualDepartureTime,
      actualArrivalTime: actualArrivalTime ?? this.actualArrivalTime,
      errorMessage: errorMessage ?? this.errorMessage,
      todayAlarms: todayAlarms ?? this.todayAlarms,
    );
  }

  bool get isTracking =>
      status == TrackingStatus.traveling ||
      status == TrackingStatus.nearDestination;
}

// ──────────────────────────────────────────────
// 메인 서비스
// ──────────────────────────────────────────────

class ArrivalTrackingNotifier extends StateNotifier<ArrivalTrackingState> {
  ArrivalTrackingNotifier() : super(const ArrivalTrackingState());

  final TmapService _tmap = TmapService();
  final LocationService _location = LocationService();
  final NotificationService _notification = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStream;
  Timer? _preCheckTimer;
  Timer? _travelUpdateTimer;

  // 설정값
  static const int _defaultBufferMinutes = 10;
  static const double _arrivalRadiusMeters = 200.0;
  static const double _nearRadiusMeters = 500.0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ──────────────────────────────────────────
  // 1. 단일 일정 출발 알람 설정
  // ──────────────────────────────────────────

  /// 일정 하나에 대해 출발 시각 계산 + 알람 설정
  Future<DepartureInfo?> setupDepartureAlarm({
    required Schedule schedule,
  }) async {
    if (schedule.location.isEmpty) return null;
    if (schedule.dateTime.isBefore(DateTime.now())) return null;

    try {
      // 1) 현재 위치
      final position = await _location.getCurrentPosition();
      if (position == null) {
        debugPrint('[ArrivalTracking] 위치 없음 → 건너뜀');
        return null;
      }

      // 2) 목적지 좌표 (T-map 장소검색)
      final places = await _tmap.searchPlace(schedule.location);
      if (places.isEmpty) {
        debugPrint('[ArrivalTracking] 장소 검색 실패: ${schedule.location}');
        return null;
      }

      final dest = places.first;

      // 3) 이동 시간 계산
      final routeMinutes = await _tmap.getRouteMinutes(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: dest.lat,
        endLng: dest.lng,
      );

      if (routeMinutes == null) {
        debugPrint('[ArrivalTracking] 경로 계산 실패');
        return null;
      }

      // 4) 지각 패턴 보정 버퍼 (punctuality_service 연동)
      final extraBuffer = await _getExtraBuffer();
      final totalBuffer = _defaultBufferMinutes + extraBuffer;

      // 5) 출발 시각 = 일정 시작 - 이동시간 - 버퍼
      final departure = schedule.dateTime.subtract(
        Duration(minutes: routeMinutes + totalBuffer),
      );

      final info = DepartureInfo(
        scheduleId: schedule.id,
        scheduleTitle: schedule.title,
        eventStartTime: schedule.dateTime,
        recommendedDeparture: departure,
        estimatedMinutes: routeMinutes,
        bufferMinutes: totalBuffer,
        location: schedule.location,
        destLat: dest.lat,
        destLng: dest.lng,
        transportMode: schedule.transportMode,
      );

      // 6) 알림 예약 (기존 NotificationService 활용)
      if (departure.isAfter(DateTime.now())) {
        await _notification.scheduleNotification(
          id: _safeId('departure_${schedule.id}'),
          title: '${schedule.transportMode.emoji} 지금 출발할 시간이에요!',
          body: '${schedule.title}까지 ${routeMinutes}분 소요 · '
              '${_formatTime(departure)} 출발 추천',
          scheduledTime: departure,
        );
      }

      // 7) 2차 교통 검증 예약 (출발 30분 전)
      _schedulePreCheck(
        schedule: schedule,
        startLat: position.latitude,
        startLng: position.longitude,
        destLat: dest.lat,
        destLng: dest.lng,
        previousMinutes: routeMinutes,
        departureTime: departure,
      );

      debugPrint(
        '[ArrivalTracking] 출발 알람: ${schedule.title} → '
        '${_formatTime(departure)} (이동 ${routeMinutes}분, 버퍼 ${totalBuffer}분)',
      );

      return info;
    } catch (e) {
      debugPrint('[ArrivalTracking] setupDepartureAlarm 오류: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────
  // 2. 오늘 일정 일괄 출발 알람 설정
  // ──────────────────────────────────────────

  /// 오늘 일정 중 장소 있는 것들 일괄 처리
  /// home_screen의 initState에서 호출
  Future<void> setupTodayAlarms(List<Schedule> schedules) async {
    final now = DateTime.now();
    final todaySchedules = schedules.where((s) {
      return s.dateTime.year == now.year &&
          s.dateTime.month == now.month &&
          s.dateTime.day == now.day &&
          s.location.isNotEmpty &&
          s.dateTime.isAfter(now);
    }).toList();

    if (todaySchedules.isEmpty) return;

    final alarms = <DepartureInfo>[];

    for (final schedule in todaySchedules) {
      final info = await setupDepartureAlarm(schedule: schedule);
      if (info != null) {
        alarms.add(info);
      }
    }

    state = state.copyWith(todayAlarms: alarms);
    debugPrint('[ArrivalTracking] 오늘 ${alarms.length}개 출발 알람 설정');
  }

  // ──────────────────────────────────────────
  // 3. 2차 교통 검증 (출발 30분 전)
  // ──────────────────────────────────────────

  void _schedulePreCheck({
    required Schedule schedule,
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    required int previousMinutes,
    required DateTime departureTime,
  }) {
    _preCheckTimer?.cancel();

    final preCheckTime =
        departureTime.subtract(const Duration(minutes: 30));
    final now = DateTime.now();

    if (preCheckTime.isBefore(now)) {
      // 이미 30분 전이면 즉시 실행
      _performPreCheck(
        schedule: schedule,
        startLat: startLat,
        startLng: startLng,
        destLat: destLat,
        destLng: destLng,
        previousMinutes: previousMinutes,
      );
      return;
    }

    _preCheckTimer = Timer(preCheckTime.difference(now), () {
      _performPreCheck(
        schedule: schedule,
        startLat: startLat,
        startLng: startLng,
        destLat: destLat,
        destLng: destLng,
        previousMinutes: previousMinutes,
      );
    });
  }

  Future<void> _performPreCheck({
    required Schedule schedule,
    required double startLat,
    required double startLng,
    required double destLat,
    required double destLng,
    required int previousMinutes,
  }) async {
    state = state.copyWith(status: TrackingStatus.preCheck);

    try {
      // 현재 위치 기준으로 재계산
      final position = await _location.getCurrentPosition();
      final currentRouteMinutes = await _tmap.getRouteMinutes(
        startLat: position?.latitude ?? startLat,
        startLng: position?.longitude ?? startLng,
        endLat: destLat,
        endLng: destLng,
      );

      if (currentRouteMinutes == null) return;

      state = state.copyWith(latestRouteMinutes: currentRouteMinutes);

      final diff = currentRouteMinutes - previousMinutes;

      // 10분 이상 악화 시 긴급 알림
      if (diff >= 10) {
        await _notification.showLocalNotification(
          title: '🚨 교통 악화 — 지금 출발하세요!',
          body: '${schedule.title}까지 예상보다 ${diff}분 더 걸려요. '
              '(${previousMinutes}분 → ${currentRouteMinutes}분)',
        );
        debugPrint('[ArrivalTracking] ⚠️ 교통 악화: +${diff}분');
      } else if (diff >= 5) {
        await _notification.showLocalNotification(
          title: '⚠️ 교통 약간 악화',
          body: '${schedule.title}까지 ${currentRouteMinutes}분 소요 예상 '
              '(${diff}분 증가)',
        );
      }

      // 상태 복원
      if (state.status == TrackingStatus.preCheck) {
        state = state.copyWith(status: TrackingStatus.scheduled);
      }
    } catch (e) {
      debugPrint('[ArrivalTracking] 2차 검증 오류: $e');
    }
  }

  // ──────────────────────────────────────────
  // 4. 이동 중 실시간 추적
  // ──────────────────────────────────────────

  /// "출발" 버튼 탭 시 호출
  Future<void> startTraveling({
    required Schedule schedule,
    required double destLat,
    required double destLng,
  }) async {
    // 위치 권한 확인
    final position = await _location.getCurrentPosition();
    if (position == null) {
      state = state.copyWith(
        status: TrackingStatus.failed,
        errorMessage: '위치 권한이 필요해요.',
      );
      return;
    }

    state = state.copyWith(
      status: TrackingStatus.traveling,
      activeScheduleId: schedule.id,
      actualDepartureTime: DateTime.now(),
      currentPosition: position,
    );

    // 위치 스트림
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(
      (pos) => _onPositionUpdate(pos, destLat, destLng, schedule),
      onError: (e) => debugPrint('[ArrivalTracking] 위치 오류: $e'),
    );

    // 3분마다 잔여 소요시간 업데이트
    _travelUpdateTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) async {
        if (state.currentPosition != null) {
          final mins = await _tmap.getRouteMinutes(
            startLat: state.currentPosition!.latitude,
            startLng: state.currentPosition!.longitude,
            endLat: destLat,
            endLng: destLng,
          );
          if (mins != null) {
            state = state.copyWith(latestRouteMinutes: mins);
          }
        }
      },
    );

    debugPrint('[ArrivalTracking] 이동 추적 시작: ${schedule.title}');
  }

  void _onPositionUpdate(
    Position position,
    double destLat,
    double destLng,
    Schedule schedule,
  ) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destLat,
      destLng,
    );

    TrackingStatus newStatus = TrackingStatus.traveling;

    if (distance <= _arrivalRadiusMeters) {
      newStatus = TrackingStatus.arrived;
      _onArrived(schedule);
    } else if (distance <= _nearRadiusMeters) {
      newStatus = TrackingStatus.nearDestination;
    }

    state = state.copyWith(
      status: newStatus,
      currentPosition: position,
      distanceToDestination: distance,
    );
  }

  // ──────────────────────────────────────────
  // 5. 도착 처리
  // ──────────────────────────────────────────

  Future<void> _onArrived(Schedule schedule) async {
    final now = DateTime.now();
    state = state.copyWith(
      status: TrackingStatus.arrived,
      actualArrivalTime: now,
    );

    // 지각 여부 계산
    final lateMinutes = now.difference(schedule.dateTime).inMinutes;
    final isLate = lateMinutes > 0;

    // Firestore 도착 기록 저장
    await _saveArrivalRecord(
      schedule: schedule,
      actualArrival: now,
      actualDeparture: state.actualDepartureTime,
      lateMinutes: isLate ? lateMinutes : 0,
    );

    // 일정 문서에 도착 정보 업데이트
    await _updateScheduleArrival(
      schedule: schedule,
      actualArrival: now,
      lateMinutes: isLate ? lateMinutes : 0,
    );

    // 도착 알림
    await _notification.showLocalNotification(
      title: isLate
          ? '📍 도착 — ${lateMinutes}분 늦었어요'
          : '🎉 정시 도착! 잘했어요!',
      body: '${schedule.title} '
          '(${_formatTime(now)} 도착)',
    );

    // 추적 정리
    stopTracking();

    debugPrint('[ArrivalTracking] 도착: ${schedule.title} '
        '(${isLate ? "${lateMinutes}분 지각" : "정시"})');
  }

  /// 수동 도착 처리 (버튼 탭)
  Future<void> markAsArrived(Schedule schedule) async {
    await _onArrived(schedule);
  }

  // ──────────────────────────────────────────
  // 6. 추적 중지
  // ──────────────────────────────────────────

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _preCheckTimer?.cancel();
    _preCheckTimer = null;
    _travelUpdateTimer?.cancel();
    _travelUpdateTimer = null;

    if (state.status != TrackingStatus.arrived) {
      state = state.copyWith(status: TrackingStatus.idle);
    }
  }

  // ──────────────────────────────────────────
  // Private: Firestore 저장
  // ──────────────────────────────────────────

  Future<void> _saveArrivalRecord({
    required Schedule schedule,
    required DateTime actualArrival,
    DateTime? actualDeparture,
    required int lateMinutes,
  }) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('arrivalRecords')
          .add({
        'scheduleId': schedule.id,
        'title': schedule.title,
        'location': schedule.location,
        'scheduledTime': Timestamp.fromDate(schedule.dateTime),
        'actualArrival': Timestamp.fromDate(actualArrival),
        'actualDeparture': actualDeparture != null
            ? Timestamp.fromDate(actualDeparture)
            : null,
        'lateMinutes': lateMinutes,
        'transportMode': schedule.transportMode.name,
        'estimatedMinutes': state.departureInfo?.estimatedMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ArrivalTracking] 도착 기록 저장 실패: $e');
    }
  }

  Future<void> _updateScheduleArrival({
    required Schedule schedule,
    required DateTime actualArrival,
    required int lateMinutes,
  }) async {
    if (_uid == null) return;
    try {
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('items')
          .doc(schedule.id)
          .update({
        'isArrived': true,
        'actualArrivalTime': Timestamp.fromDate(actualArrival),
        'lateMinutes': lateMinutes,
      });
    } catch (e) {
      debugPrint('[ArrivalTracking] 일정 도착 업데이트 실패: $e');
    }
  }

  // ──────────────────────────────────────────
  // Private: 유틸
  // ──────────────────────────────────────────

  Future<int> _getExtraBuffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('punctuality_buffer_minutes') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static int _safeId(String input) {
    var hash = 0;
    for (final c in input.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '키보 — 이동 중',
          notificationText: '목적지까지 이동 추적 중이에요',
          enableWakeLock: true,
          notificationChannelName: 'kibo_tracking',
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
