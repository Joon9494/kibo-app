// =====================================================
// 📁 lib/features/calendar/schedule_model.dart
// =====================================================

import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── 교통수단 열거형 ───────────────────────────────────
enum TransportMode {
  car,
  transit,
  walk,
  bicycle,
  unknown,
}

extension TransportModeLabel on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.car:     return '자동차';
      case TransportMode.transit: return '대중교통';
      case TransportMode.walk:    return '도보';
      case TransportMode.bicycle: return '자전거';
      case TransportMode.unknown: return '미설정';
    }
  }

  String get emoji {
    switch (this) {
      case TransportMode.car:     return '🚗';
      case TransportMode.transit: return '🚇';
      case TransportMode.walk:    return '🚶';
      case TransportMode.bicycle: return '🚴';
      case TransportMode.unknown: return '❓';
    }
  }

  static TransportMode fromString(String? value) {
    switch (value) {
      case 'car':     return TransportMode.car;
      case 'transit': return TransportMode.transit;
      case 'walk':    return TransportMode.walk;
      case 'bicycle': return TransportMode.bicycle;
      default:        return TransportMode.unknown;
    }
  }
}

// ── 중요도 열거형 ─────────────────────────────────────
enum Importance { high, normal, low }

extension ImportanceLabel on Importance {
  String get label {
    switch (this) {
      case Importance.high:   return '높음';
      case Importance.normal: return '보통';
      case Importance.low:    return '낮음';
    }
  }

  static Importance fromString(String? value) {
    switch (value) {
      case 'high': return Importance.high;
      case 'low':  return Importance.low;
      default:     return Importance.normal;
    }
  }
}

// ── 기본 태그 색상 ────────────────────────────────────
class TagColors {
  static const Map<String, String> defaults = {
    '업무': '#4A90E2',
    '개인': '#5BAD6F',
    '의료': '#E24A4A',
    '여행': '#F5A623',
    '쇼핑': '#9B59B6',
    '가족': '#E67E22',
    '기타': '#95A5A6',
  };

  static String colorFor(String tag) =>
      defaults[tag] ?? defaults['기타']!;

  static String calendarNameFor(String tag) =>
      defaults.containsKey(tag) ? 'KIBO-$tag' : 'KIBO-기타';
}

// ── Schedule 모델 ─────────────────────────────────────
class Schedule {
  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final String description;
  final String uid;
  final String googleEventId;
  final DateTime? createdAt;
  final TransportMode transportMode;
  final String companions;
  final Importance importance;
  final int reminderMinutes;
  final bool isArrived;
  final DateTime? actualArrivalTime;
  final int? lateMinutes;

  // ✅ 불변 리스트 — 외부에서 add/remove 불가
  final UnmodifiableListView<String> tags;

  Schedule({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.description,
    required this.uid,
    this.googleEventId = '',
    this.createdAt,
    List<String> tags = const [],
    this.transportMode = TransportMode.unknown,
    this.companions = '혼자',
    this.importance = Importance.normal,
    this.reminderMinutes = 60,
    this.isArrived = false,
    this.actualArrivalTime,
    this.lateMinutes,
  }) : tags = UnmodifiableListView(tags);

  // ── Firestore → Schedule ──────────────────────────
  factory Schedule.fromMap(String id, Map<String, dynamic> map) {
    // ✅ String 타입 포함 안전한 날짜 파싱
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    // ✅ tags 타입 안전 캐스팅
    List<String> parseTags(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
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
      tags: parseTags(map['tags']),
      transportMode:
          TransportModeLabel.fromString(map['transportMode']?.toString()),
      companions: map['companions']?.toString() ?? '혼자',
      importance:
          ImportanceLabel.fromString(map['importance']?.toString()),
      reminderMinutes: map['reminderMinutes'] as int? ?? 60,
      isArrived: map['isArrived'] as bool? ?? false,
      actualArrivalTime: map['actualArrivalTime'] != null
          ? parseDateTime(map['actualArrivalTime'])
          : null,
      lateMinutes: map['lateMinutes'] as int?,
    );
  }

  // ── Schedule → Firestore ──────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dateTime': dateTime,
      'location': location,
      'description': description,
      'uid': uid,
      'googleEventId': googleEventId,
      'createdAt': createdAt ?? DateTime.now(),
      'tags': tags.toList(),
      'transportMode': transportMode.name,
      'companions': companions,
      'importance': importance.name,
      'reminderMinutes': reminderMinutes,
      'isArrived': isArrived,
      'actualArrivalTime': actualArrivalTime,
      'lateMinutes': lateMinutes,
    };
  }

  // ✅ 객체 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Schedule) return false;
    return id == other.id &&
        title == other.title &&
        dateTime == other.dateTime &&
        location == other.location &&
        description == other.description &&
        uid == other.uid &&
        googleEventId == other.googleEventId &&
        transportMode == other.transportMode &&
        companions == other.companions &&
        importance == other.importance &&
        reminderMinutes == other.reminderMinutes &&
        isArrived == other.isArrived &&
        lateMinutes == other.lateMinutes &&
        _listEquals(tags.toList(), other.tags.toList());
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        dateTime,
        location,
        description,
        uid,
        googleEventId,
        transportMode,
        companions,
        importance,
        reminderMinutes,
        isArrived,
        lateMinutes,
        Object.hashAll(tags),
      );

  // 리스트 동등성 비교 헬퍼
  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── copyWith ──────────────────────────────────────
  Schedule copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? location,
    String? description,
    String? uid,
    String? googleEventId,
    DateTime? createdAt,
    List<String>? tags,
    TransportMode? transportMode,
    String? companions,
    Importance? importance,
    int? reminderMinutes,
    bool? isArrived,
    DateTime? actualArrivalTime,
    int? lateMinutes,
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
      tags: tags ?? this.tags.toList(),
      transportMode: transportMode ?? this.transportMode,
      companions: companions ?? this.companions,
      importance: importance ?? this.importance,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isArrived: isArrived ?? this.isArrived,
      actualArrivalTime: actualArrivalTime ?? this.actualArrivalTime,
      lateMinutes: lateMinutes ?? this.lateMinutes,
    );
  }

  // ── 편의 메서드 ───────────────────────────────────
  String get tagsString => tags.map((t) => '#$t').join(' ');

  String get primaryTagColor =>
      tags.isNotEmpty ? TagColors.colorFor(tags.first) : TagColors.defaults['기타']!;

  String get googleCalendarName =>
      tags.isNotEmpty ? TagColors.calendarNameFor(tags.first) : 'KIBO-기타';
}