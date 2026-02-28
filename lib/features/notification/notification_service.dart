// =====================================================
// 📁 lib/features/notification/notification_service.dart
// =====================================================

import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../map/tmap_service.dart';
import '../map/location_service.dart';
import '../calendar/schedule_model.dart';

// ── FCM 백그라운드 핸들러 ─────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  debugPrint('백그라운드 메시지: ${message.notification?.title}');
}

// ── AlarmManager 콜백 (Android 전용, top-level 필수) ──
@pragma('vm:entry-point')
Future<void> realtimeAlertCallback(int alarmId) async {
  final prefs = await SharedPreferences.getInstance();
  final dataJson = prefs.getString('alarm_$alarmId');
  if (dataJson == null) {
    debugPrint('알람 데이터 없음: $alarmId');
    return;
  }
  final data = jsonDecode(dataJson) as Map<String, dynamic>;
  await _handleRealtimeAlertTask(alarmId, data);
  await prefs.remove('alarm_$alarmId');
}

// ✅ 타임존 약어 → IANA 매핑
// DateTime.now().timeZoneName은 'KST' 같은 약어를 반환
// timezone 패키지는 'Asia/Seoul' 같은 IANA ID를 요구
const _tzAbbrevToIana = {
  'KST': 'Asia/Seoul',
  'JST': 'Asia/Tokyo',
  'CST': 'Asia/Shanghai',
  'HKT': 'Asia/Hong_Kong',
  'SGT': 'Asia/Singapore',
  'IST': 'Asia/Kolkata',
  'EST': 'America/New_York',
  'EDT': 'America/New_York',
  'CST2': 'America/Chicago',
  'CDT': 'America/Chicago',
  'MST': 'America/Denver',
  'MDT': 'America/Denver',
  'PST': 'America/Los_Angeles',
  'PDT': 'America/Los_Angeles',
  'GMT': 'Europe/London',
  'BST': 'Europe/London',
  'CET': 'Europe/Paris',
  'CEST': 'Europe/Paris',
  'UTC': 'UTC',
};

// ── timezone 초기화 헬퍼 ─────────────────────────────
void _initTimezone() {
  tz_data.initializeTimeZones();
  try {
    // ✅ 약어를 IANA ID로 변환 후 설정
    final abbr = DateTime.now().timeZoneName;
    final ianaId = _tzAbbrevToIana[abbr] ?? 'Asia/Seoul';
    tz.setLocalLocation(tz.getLocation(ianaId));
    debugPrint('Timezone 설정: $abbr → $ianaId');
  } catch (e) {
    debugPrint('Timezone 설정 실패, Asia/Seoul 사용: $e');
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  }
}

// ── 실시간 알림 처리 (백그라운드 공용) ───────────────
Future<void> _handleRealtimeAlertTask(
    int notifId, Map<String, dynamic> data) async {
  _initTimezone();

  final localNotifications = fln.FlutterLocalNotificationsPlugin();
  const androidSettings =
      fln.AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
      const fln.InitializationSettings(android: androidSettings));

  final scheduleTitle = data['scheduleTitle'] as String? ?? '';
  final location     = data['location']      as String? ?? '';
  final eventTimeMs  = data['eventTimeMs']   as int?    ?? 0;
  final transportStr = data['transportMode'] as String? ?? 'unknown';
  final label        = data['label']         as String? ?? '';

  final eventTime = DateTime.fromMillisecondsSinceEpoch(eventTimeMs);
  final mode = TransportMode.values.firstWhere(
    (e) => e.name == transportStr,
    orElse: () => TransportMode.unknown,
  );

  final locationService = LocationService();
  final tmapService     = TmapService();

  Future<void> showNotif(String body) async {
    await localNotifications.show(
      notifId,
      '⏰ $scheduleTitle $label',
      body,
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'kibo_channel', 'KIBO 알림',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  try {
    final position = await locationService.getCurrentPosition();
    if (position == null || location.isEmpty) {
      await showNotif('출발 준비를 해주세요. 현재 위치를 확인할 수 없어요.');
      return;
    }

    final places = await tmapService.searchPlace(location);
    if (places.isEmpty) {
      await showNotif('$location 방향으로 출발을 준비해주세요.');
      return;
    }

    final routeMinutes = await tmapService.getRouteMinutes(
      startLat: position.latitude,
      startLng: position.longitude,
      endLat: places.first.lat,
      endLng: places.first.lng,
    );

    if (routeMinutes == null) {
      await showNotif('경로를 계산하지 못했어요. 출발 시간을 확인해주세요.');
      return;
    }

    final emoji     = NotificationService.transportEmoji(mode);
    final remaining = eventTime.difference(DateTime.now()).inMinutes;
    final isLate    = routeMinutes >= remaining;

    await showNotif(isLate
        ? '⚠️ 지금 당장 출발하세요! 소요시간 $routeMinutes분인데 $remaining분 남았어요.'
        : '$emoji 현재 소요시간 $routeMinutes분이에요. '
            '${remaining - routeMinutes}분 여유 있어요 😊');
  } catch (e) {
    debugPrint('백그라운드 알림 오류: $e');
    await showNotif('출발 준비를 확인해주세요.');
  }
}

// ── NotificationService ───────────────────────────────
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging          = FirebaseMessaging.instance;
  final _localNotifications = fln.FlutterLocalNotificationsPlugin();
  bool _initialized         = false;

  // ✅ 안전한 알림 ID (31비트 범위)
  static int _safeNotifId(String input) {
    var hash = 0;
    for (final c in input.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return hash;
  }

  // ✅ 수동 알람 ID 목록 저장 키
  static String _manualAlarmsKey(String scheduleId) =>
      'manual_alarm_ids_$scheduleId';

  // ── 초기화 ────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _initTimezone();

    // ✅ Android 전용 AlarmManager 초기화
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }

    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('알림 권한: ${settings.authorizationStatus}');

    const androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
        const fln.InitializationSettings(android: androidSettings));

    const channel = fln.AndroidNotificationChannel(
      'kibo_channel', 'KIBO 알림',
      description: 'KIBO 일정 알림',
      importance: fln.Importance.high,
    );

    if (Platform.isAndroid) {
      final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen((message) {
      showLocalNotification(
        title: message.notification?.title ?? 'KIBO',
        body: message.notification?.body ?? '',
      );
    });

    final token = await _messaging.getToken();
    debugPrint('FCM 토큰: $token');
  }

  // ── 교통수단 이모티콘 ─────────────────────────────
  static String transportEmoji(TransportMode mode) {
    switch (mode) {
      case TransportMode.car:     return '🚗';
      case TransportMode.transit: return '🚇';
      case TransportMode.walk:    return '🚶';
      case TransportMode.bicycle: return '🚴';
      default:                    return '🚗';
    }
  }

  // ── 로컬 알림 즉시 표시 ───────────────────────────
  Future<void> showLocalNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    await _localNotifications.show(
      id ?? _safeNotifId('${DateTime.now().millisecondsSinceEpoch}'),
      title,
      body,
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'kibo_channel', 'KIBO 알림',
          channelDescription: 'KIBO 일정 알림',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── OS 알림 예약 (zonedSchedule) ──────────────────
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'kibo_channel', 'KIBO 알림',
          channelDescription: 'KIBO 일정 알림',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode:
          fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: fln
          .UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('OS 알림 예약: $title → $scheduledTime');
  }

  // ── ✅ 자동 알람 ───────────────────────────────────
  Future<void> scheduleAutoAlarm({
    required Schedule schedule,
    required int routeMinutes,
    int bufferMinutes = 10,
    int extraBufferMinutes = 0,
  }) async {
    final departureTime = schedule.dateTime.subtract(
      Duration(minutes: routeMinutes + bufferMinutes + extraBufferMinutes),
    );
    if (departureTime.isBefore(DateTime.now())) return;

    final emoji = transportEmoji(schedule.transportMode);
    final h = schedule.dateTime.hour.toString().padLeft(2, '0');
    final m = schedule.dateTime.minute.toString().padLeft(2, '0');
    final extra = extraBufferMinutes > 0
        ? ' (여유 ${extraBufferMinutes}분 포함)' : '';

    await scheduleNotification(
      id: _safeNotifId('auto_depart_${schedule.id}'),
      title: '$emoji 지금 출발할 시간이에요!',
      body: '${schedule.title} ($h:$m)까지 $routeMinutes분 걸려요.$extra',
      scheduledTime: departureTime,
    );

    // ✅ Android 전용
    if (Platform.isAndroid) {
      await scheduleRealtimeAlerts(schedule: schedule);
    }

    debugPrint('자동 알람 설정: ${schedule.title} → 출발 $departureTime');
  }

  // ── ✅ 수동 알람 (ID 추적 포함) ───────────────────
  Future<void> scheduleManualAlarm({
    required Schedule schedule,
    required DateTime alarmTime,
  }) async {
    if (alarmTime.isBefore(DateTime.now())) return;

    final h = schedule.dateTime.hour.toString().padLeft(2, '0');
    final m = schedule.dateTime.minute.toString().padLeft(2, '0');
    final notifId = _safeNotifId(
        'manual_${schedule.id}_${alarmTime.millisecondsSinceEpoch}');

    await scheduleNotification(
      id: notifId,
      title: '⏰ ${schedule.title}',
      body: '$h:$m에 일정이 있어요!',
      scheduledTime: alarmTime,
    );

    // ✅ 수동 알람 ID 목록에 추가 (삭제 시 회수용)
    final prefs = await SharedPreferences.getInstance();
    final key = _manualAlarmsKey(schedule.id);
    final existing = prefs.getStringList(key) ?? [];
    existing.add(notifId.toString());
    await prefs.setStringList(key, existing);

    debugPrint('수동 알람 설정: ${schedule.title} → $alarmTime (ID: $notifId)');
  }

  // ── ✅ D-2h / D-1h AlarmManager (Android 전용) ────
  Future<void> scheduleRealtimeAlerts({
    required Schedule schedule,
  }) async {
    if (!Platform.isAndroid) return;
    if (schedule.location.isEmpty) return;
    if (schedule.dateTime.isBefore(DateTime.now())) return;

    final prefs = await SharedPreferences.getInstance();
    final commonData = {
      'scheduleTitle': schedule.title,
      'location':      schedule.location,
      'eventTimeMs':   schedule.dateTime.millisecondsSinceEpoch,
      'transportMode': schedule.transportMode.name,
    };

    // D-2시간
    final twoHoursBefore =
        schedule.dateTime.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(DateTime.now())) {
      final id2h = _safeNotifId('realtime_2h_${schedule.id}');
      await prefs.setString('alarm_$id2h', jsonEncode({
        ...commonData, 'notifId': id2h, 'label': '2시간 전',
      }));
      await AndroidAlarmManager.oneShotAt(
        twoHoursBefore, id2h, realtimeAlertCallback,
        exact: true, wakeup: true, rescheduleOnReboot: true,
      );
      debugPrint('D-2시간 AlarmManager 예약: ${schedule.title}');
    }

    // D-1시간
    final oneHourBefore =
        schedule.dateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(DateTime.now())) {
      final id1h = _safeNotifId('realtime_1h_${schedule.id}');
      await prefs.setString('alarm_$id1h', jsonEncode({
        ...commonData, 'notifId': id1h, 'label': '1시간 전',
      }));
      await AndroidAlarmManager.oneShotAt(
        oneHourBefore, id1h, realtimeAlertCallback,
        exact: true, wakeup: true, rescheduleOnReboot: true,
      );
      debugPrint('D-1시간 AlarmManager 예약: ${schedule.title}');
    }
  }

  // ── ✅ 알림 전체 취소 (자동 + 수동 + D-2h/D-1h) ──
  Future<void> cancelScheduleAlarms(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();

    // 자동 알람 취소
    final idDepart = _safeNotifId('auto_depart_$scheduleId');
    await _localNotifications.cancel(idDepart);

    // ✅ Android 전용 AlarmManager 취소
    if (Platform.isAndroid) {
      final id2h = _safeNotifId('realtime_2h_$scheduleId');
      final id1h = _safeNotifId('realtime_1h_$scheduleId');
      await AndroidAlarmManager.cancel(id2h);
      await AndroidAlarmManager.cancel(id1h);
      await prefs.remove('alarm_$id2h');
      await prefs.remove('alarm_$id1h');
    }

    // ✅ 수동 알람 전체 취소 (고아 알람 방지)
    final manualKey = _manualAlarmsKey(scheduleId);
    final manualIds = prefs.getStringList(manualKey) ?? [];
    for (final idStr in manualIds) {
      final id = int.tryParse(idStr);
      if (id != null) {
        await _localNotifications.cancel(id);
        debugPrint('수동 알람 취소: $id');
      }
    }
    await prefs.remove(manualKey);

    debugPrint('알람 전체 취소 완료: $scheduleId');
  }
}