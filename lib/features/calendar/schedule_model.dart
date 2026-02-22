// =====================================================
// 📁 lib/features/calendar/schedule_model.dart
// 역할: 일정 데이터 구조 정의
//       Firestore에 저장/불러올 때 이 구조를 사용
//       예: Schedule 객체 → Firestore 문서로 변환
//           Firestore 문서 → Schedule 객체로 변환
// =====================================================

class Schedule {
  final String id;          // Firestore 문서 ID
  final String title;       // 일정 제목
  final DateTime dateTime;  // 날짜 + 시간
  final String location;    // 장소
  final String description; // 추가 설명
  final String uid;         // 작성자 uid

  Schedule({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.description,
    required this.uid,
  });

  // ── Firestore 문서 → Schedule 객체 변환 ──────────
  // Firestore에서 데이터를 읽어올 때 사용
  factory Schedule.fromMap(String id, Map<String, dynamic> map) {
    return Schedule(
      id: id,
      title: map['title'] ?? '',
      // Firestore Timestamp → DateTime 변환
      dateTime: (map['dateTime'] as dynamic).toDate(),
      location: map['location'] ?? '',
      description: map['description'] ?? '',
      uid: map['uid'] ?? '',
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
      'createdAt': DateTime.now(),
    };
  }
}