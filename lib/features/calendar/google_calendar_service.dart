import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
    ],
  );

  // 인증된 HTTP 클라이언트 생성
  Future<http.Client?> _getAuthClient() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;

      final auth = await account.authHeaders;
      return _AuthenticatedClient(http.Client(), auth);
    } catch (e) {
      debugPrint('캘린더 인증 오류: $e');
      return null;
    }
  }

  // KIBO 일정 → Google 캘린더 추가 후 이벤트 ID 반환
  Future<String?> addEvent({
    required String title,
    required DateTime dateTime,
    String location = '',
    String description = '',
  }) async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      if (client == null) return null;

      final calendarApi = gcal.CalendarApi(client);

      final event = gcal.Event(
        summary: title,
        location: location.isNotEmpty ? location : null,
        description: description.isNotEmpty ? description : null,
        start: gcal.EventDateTime(
          dateTime: dateTime.toUtc(),
          timeZone: 'Asia/Seoul',
        ),
        end: gcal.EventDateTime(
          dateTime: dateTime.add(const Duration(hours: 1)).toUtc(),
          timeZone: 'Asia/Seoul',
        ),
      );

      final result = await calendarApi.events.insert(event, 'primary');
      return result.id; // 이벤트 ID 반환
    } catch (e) {
      debugPrint('캘린더 추가 오류: $e');
      return null;
    } finally {
      client?.close();
    }
  }

  // Google 캘린더 이벤트 삭제
  Future<bool> deleteEvent(String googleEventId) async {
    if (googleEventId.isEmpty) return false;
    http.Client? client;
    try {
      client = await _getAuthClient();
      if (client == null) return false;

      final calendarApi = gcal.CalendarApi(client);
      await calendarApi.events.delete('primary', googleEventId);
      return true;
    } catch (e) {
      debugPrint('캘린더 삭제 오류: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  // Google 캘린더 → KIBO로 일정 가져오기 (-7일 ~ +7일)
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      if (client == null) return [];

      final calendarApi = gcal.CalendarApi(client);
      final now = DateTime.now();

      final events = await calendarApi.events.list(
        'primary',
        timeMin: now.subtract(const Duration(days: 7)).toUtc(),
        timeMax: now.add(const Duration(days: 7)).toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null) return [];

      return events.items!.map((e) {
        // 종일 일정은 dateTime 대신 date 필드 사용
        final DateTime start;
        if (e.start?.dateTime != null) {
          start = e.start!.dateTime!;
        } else if (e.start?.date != null) {
          final d = e.start!.date!;
          start = DateTime(d.year, d.month, d.day);
        } else {
          start = DateTime.now();
        }

        return {
          'title': e.summary ?? '제목 없음',
          'date':
              '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
          'time':
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
          'location': e.location ?? '',
          'description': e.description ?? '',
          'googleEventId': e.id ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('캘린더 가져오기 오류: $e');
      return [];
    } finally {
      client?.close();
    }
  }
}

// 인증 헤더를 포함한 HTTP 클라이언트 래퍼
class _AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}