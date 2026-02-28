// =====================================================
// 📁 lib/features/arrival/punctuality_service.dart
// 역할: 9단계 — 지각 패턴 학습 서비스
//       도착 기록 분석 → 사용자별 추천 버퍼 자동 계산
//       시간대별/요일별 패턴 학습
// =====================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────
// Riverpod Provider
// ──────────────────────────────────────────────

final punctualityProvider =
    StateNotifierProvider<PunctualityNotifier, PunctualityState>(
  (ref) => PunctualityNotifier(),
);

// ──────────────────────────────────────────────
// 상태 모델
// ──────────────────────────────────────────────

class PunctualityState {
  final PunctualityProfile? profile;
  final List<ArrivalRecord> recentRecords;
  final bool isLoading;

  const PunctualityState({
    this.profile,
    this.recentRecords = const [],
    this.isLoading = false,
  });

  PunctualityState copyWith({
    PunctualityProfile? profile,
    List<ArrivalRecord>? recentRecords,
    bool? isLoading,
  }) {
    return PunctualityState(
      profile: profile ?? this.profile,
      recentRecords: recentRecords ?? this.recentRecords,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 사용자 시간 관리 프로필
class PunctualityProfile {
  final int totalTrips;
  final int onTimeCount;
  final int lateCount;
  final int earlyCount;
  final double avgLateMinutes;    // 평균 지각 시간
  final int recommendedBuffer;    // 학습된 추천 버퍼 (분)
  final Map<String, double> timeSlotAvg; // 시간대별 평균 지각
  final DateTime? lastUpdated;

  const PunctualityProfile({
    this.totalTrips = 0,
    this.onTimeCount = 0,
    this.lateCount = 0,
    this.earlyCount = 0,
    this.avgLateMinutes = 0,
    this.recommendedBuffer = 0,
    this.timeSlotAvg = const {},
    this.lastUpdated,
  });

  double get onTimeRate =>
      totalTrips > 0 ? onTimeCount / totalTrips * 100 : 0;

  double get lateRate =>
      totalTrips > 0 ? lateCount / totalTrips * 100 : 0;

  String get grade {
    if (totalTrips < 5) return '데이터 수집 중';
    if (onTimeRate >= 90) return '⏰ 시간 관리 달인';
    if (onTimeRate >= 75) return '👍 양호';
    if (onTimeRate >= 60) return '🔔 개선 가능';
    return '⚠️ 주의 필요';
  }

  /// 브리핑용 한줄 요약
  String get briefingSummary {
    if (totalTrips < 3) return '';
    return '정시 도착률 ${onTimeRate.toStringAsFixed(0)}% · '
        '추천 여유시간 ${recommendedBuffer}분';
  }

  Map<String, dynamic> toMap() => {
        'totalTrips': totalTrips,
        'onTimeCount': onTimeCount,
        'lateCount': lateCount,
        'earlyCount': earlyCount,
        'avgLateMinutes': avgLateMinutes,
        'recommendedBuffer': recommendedBuffer,
        'timeSlotAvg': timeSlotAvg,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  factory PunctualityProfile.fromMap(Map<String, dynamic> map) {
    return PunctualityProfile(
      totalTrips: map['totalTrips'] as int? ?? 0,
      onTimeCount: map['onTimeCount'] as int? ?? 0,
      lateCount: map['lateCount'] as int? ?? 0,
      earlyCount: map['earlyCount'] as int? ?? 0,
      avgLateMinutes:
          (map['avgLateMinutes'] as num?)?.toDouble() ?? 0,
      recommendedBuffer: map['recommendedBuffer'] as int? ?? 0,
      timeSlotAvg:
          (map['timeSlotAvg'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ) ??
              {},
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }
}

/// 개별 도착 기록
class ArrivalRecord {
  final String scheduleId;
  final String title;
  final DateTime scheduledTime;
  final DateTime actualArrival;
  final int lateMinutes; // +: 늦음, 0: 정시, -: 일찍
  final String transportMode;

  const ArrivalRecord({
    required this.scheduleId,
    required this.title,
    required this.scheduledTime,
    required this.actualArrival,
    required this.lateMinutes,
    required this.transportMode,
  });

  bool get wasOnTime => lateMinutes <= 3;
  bool get wasLate => lateMinutes > 3;
  bool get wasEarly => lateMinutes < -3;

  factory ArrivalRecord.fromMap(Map<String, dynamic> map) {
    return ArrivalRecord(
      scheduleId: map['scheduleId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      scheduledTime:
          (map['scheduledTime'] as Timestamp).toDate(),
      actualArrival:
          (map['actualArrival'] as Timestamp).toDate(),
      lateMinutes: map['lateMinutes'] as int? ?? 0,
      transportMode: map['transportMode'] as String? ?? 'unknown',
    );
  }
}

// ──────────────────────────────────────────────
// 메인 서비스
// ──────────────────────────────────────────────

class PunctualityNotifier extends StateNotifier<PunctualityState> {
  PunctualityNotifier() : super(const PunctualityState());

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _minRecords = 5;
  static const int _maxRecords = 30;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ──────────────────────────────────────────
  // 1. 프로필 로드
  // ──────────────────────────────────────────

  Future<void> loadProfile() async {
    if (_uid == null) return;
    state = state.copyWith(isLoading: true);

    try {
      // 프로필
      final profileDoc = await _db
          .collection('schedules')
          .doc(_uid)
          .collection('punctuality')
          .doc('profile')
          .get();

      PunctualityProfile? profile;
      if (profileDoc.exists) {
        profile = PunctualityProfile.fromMap(profileDoc.data()!);
      }

      // 최근 기록
      final recordsSnap = await _db
          .collection('schedules')
          .doc(_uid)
          .collection('arrivalRecords')
          .orderBy('createdAt', descending: true)
          .limit(_maxRecords)
          .get();

      final records = recordsSnap.docs
          .map((doc) => ArrivalRecord.fromMap(doc.data()))
          .toList();

      state = state.copyWith(
        profile: profile,
        recentRecords: records,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[Punctuality] 프로필 로드 실패: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ──────────────────────────────────────────
  // 2. 프로필 재학습 (도착 기록 추가 시 호출)
  // ──────────────────────────────────────────

  Future<void> recalculateProfile() async {
    if (_uid == null) return;

    try {
      final recordsSnap = await _db
          .collection('schedules')
          .doc(_uid)
          .collection('arrivalRecords')
          .orderBy('createdAt', descending: true)
          .limit(_maxRecords)
          .get();

      if (recordsSnap.docs.length < _minRecords) {
        debugPrint('[Punctuality] 데이터 부족 (${recordsSnap.docs.length}/$_minRecords)');
        return;
      }

      final records = recordsSnap.docs.map((d) => d.data()).toList();

      // 통계 계산
      int onTime = 0, late = 0, early = 0;
      double totalLate = 0;
      final timeSlotLate = <String, List<int>>{};

      for (final r in records) {
        final mins = r['lateMinutes'] as int? ?? 0;

        if (mins > 3) {
          late++;
          totalLate += mins;
        } else if (mins < -3) {
          early++;
        } else {
          onTime++;
        }

        // 시간대별 집계 (3시간 단위)
        final scheduled = r['scheduledTime'] as Timestamp?;
        if (scheduled != null) {
          final hour = scheduled.toDate().hour;
          final slot = '${(hour ~/ 3 * 3).toString().padLeft(2, '0')}-'
              '${((hour ~/ 3 + 1) * 3).toString().padLeft(2, '0')}';
          timeSlotLate.putIfAbsent(slot, () => []).add(mins);
        }
      }

      final total = records.length;
      final avgLate = late > 0 ? totalLate / late : 0.0;

      // 시간대별 평균
      final timeSlotAvg = timeSlotLate.map(
        (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
      );

      // 추천 버퍼: 평균 지각 + 표준편차 × 0.5
      final lateValues = records
          .map((r) => (r['lateMinutes'] as int? ?? 0).toDouble())
          .where((v) => v > 0)
          .toList();
      final stdDev = _stdDev(lateValues);
      final rawBuffer = (avgLate + stdDev * 0.5).ceil();
      final recommendedBuffer = rawBuffer.clamp(0, 30);

      final profile = PunctualityProfile(
        totalTrips: total,
        onTimeCount: onTime,
        lateCount: late,
        earlyCount: early,
        avgLateMinutes: avgLate,
        recommendedBuffer: recommendedBuffer,
        timeSlotAvg: timeSlotAvg.map(
          (k, v) => MapEntry(k, double.parse(v.toStringAsFixed(1))),
        ),
        lastUpdated: DateTime.now(),
      );

      // Firestore 저장
      await _db
          .collection('schedules')
          .doc(_uid)
          .collection('punctuality')
          .doc('profile')
          .set(profile.toMap());

      // SharedPreferences에도 저장 (arrival_tracking에서 빠르게 접근)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('punctuality_buffer_minutes', recommendedBuffer);

      state = state.copyWith(profile: profile);

      debugPrint(
        '[Punctuality] 갱신 완료: 정시율 ${profile.onTimeRate.toStringAsFixed(0)}%, '
        '추천 버퍼 ${recommendedBuffer}분',
      );
    } catch (e) {
      debugPrint('[Punctuality] 프로필 갱신 실패: $e');
    }
  }

  // ──────────────────────────────────────────
  // 3. 브리핑용 인사이트
  // ──────────────────────────────────────────

  String? generateInsight() {
    final profile = state.profile;
    if (profile == null || profile.totalTrips < _minRecords) return null;

    if (profile.lateRate > 40) {
      return '최근 이동의 ${profile.lateRate.toStringAsFixed(0)}%에서 '
          '늦게 도착했어요. 출발 시간을 ${profile.recommendedBuffer}분 '
          '앞당기면 도움이 될 거예요.';
    }

    if (profile.onTimeRate >= 85) {
      return '정시 도착률 ${profile.onTimeRate.toStringAsFixed(0)}%! '
          '시간 관리를 잘 하고 계세요 👏';
    }

    // 특정 시간대 주의
    final worstSlot = _findWorstSlot(profile.timeSlotAvg);
    if (worstSlot != null) {
      return '${worstSlot.key} 시간대에 평균 '
          '${worstSlot.value.toStringAsFixed(0)}분 늦는 경향이 있어요.';
    }

    return null;
  }

  // ──────────────────────────────────────────
  // Private 유틸
  // ──────────────────────────────────────────

  double _stdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSq = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSq / values.length);
  }

  MapEntry<String, double>? _findWorstSlot(Map<String, double> avg) {
    if (avg.isEmpty) return null;
    final worst = avg.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    return worst.value > 5 ? worst : null; // 5분 이상만 의미
  }
}
