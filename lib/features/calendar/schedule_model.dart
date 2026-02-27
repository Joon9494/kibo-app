// =====================================================
// 📁 lib/features/calendar/schedule_model.dart
// 역할: 일정 데이터 구조 정의
//       Firestore에 저장/불러올 때 이 구조를 사용
//       예: Schedule 객체 → Firestore 문서로 변환
//           Firestore 문서 → Schedule 객체로 변환
// =====================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule {
  final String id;             // Firestore 문서 ID
  final String title;          // 일정 제목
  final DateTime dateTime;     // 날짜 + 시간
  final String location;       // 장소
  final String description;    // 추가 설명
  final String uid;            // 작성자 uid
  final String googleEventId;  // Google 캘린더 이벤트 ID
  final DateTime? createdAt;   // 생성일자

  Schedule({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.description,
    required this.uid,
    this.googleEventId = '',
    this.createdAt,
  });

  // ── Firestore 문서 → Schedule 객체 변환 ──────────
  // Firestore에서 데이터를 읽어올 때 사용
  factory Schedule.fromMap(String id, Map<String, dynamic> map) {
    // Timestamp 타입 안전 변환 — 누락되거나 타입이 다르면 현재 시간으로 대체
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Schedule(
      id: id,
      title: map['title']?.toString() ?? '',
      dateTime: parseDateTime(map['dateTime']),
      location: map['location']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      uid: map['uid']?.toString() ?? '',
      googleEventId: map['googleEventId']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? parseDateTime(map['createdAt'])
          : null,
    );
  }

  // ── Schedule 객체 → Firestore 문서 변환 ──────────
  // Firestore에 저장할 때 사용
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dateTime': dateTime,       // Firestore가 자동으로 Timestamp로 변환
      'location': location,
      'description': description,
      'uid': uid,
      'googleEventId': googleEventId,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  // ── 특정 필드만 교체한 새 객체 반환 ──────────────
  // 불변 객체 유지하면서 필드 업데이트 시 사용
  Schedule copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? location,
    String? description,
    String? uid,
    String? googleEventId,
    DateTime? createdAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      description: description ?? this.description,
      uid: uid ?? this.uid,
      googleEventId: googleEventId ?? this.googleEventId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}