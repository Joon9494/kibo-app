// =====================================================
// 📁 lib/features/calendar/google_calendar_service.dart
// =====================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'schedule_model.dart';

// ── 인증 실패 예외 ─────────────────────────────────────
class CalendarAuthException implements Exception {
  final String message;
  CalendarAuthException(this.message);
  @override
  String toString() => 'CalendarAuthException: $message';
}

class GoogleCalendarService {
  final _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
    ],
  );

  // ── 기기 시간대 동적 조회 ─────────────────────────
  String get _localTimeZone {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes =
        (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return 'Etc/GMT${sign == '+' ? '-' : '+'}${offset.inHours.abs()}';
  }

  // ── 인증 클라이언트 — 실패 시 예외 throw ─────────
  Future<http.Client> _getAuthClient() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();

      // ✅ 조용한 인증 실패 시 명시적 예외
      if (account == null) {
        throw CalendarAuthException(
            '구글 계정 인증이 필요해요. 다시 로그인해주세요.');
      }

      final auth = await account.authHeaders;
      return _AuthenticatedClient(http.Client(), auth);
    } catch (e) {
      if (e is CalendarAuthException) rethrow;
      debugPrint('캘린더 인증 오류: $e');
      throw CalendarAuthException('인증 오류: $e');
    }
  }

  // ── 지수 백오프 재시도 ────────────────────────────
  Future<T> _withBackoff<T>(
    Future<T> Function() fn, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        final delay = Duration(milliseconds: 500 * (1 << attempt));
        debugPrint('재시도 $attempt/$maxRetries — ${delay.inMilliseconds}ms 후');
        await Future.delayed(delay);
      }
    }
  }

  // ── HEX → Google colorId 변환 ────────────────────
  String _hexToGoogleColorId(String hex) {
    const colorMap = {
      '#4A90E2': '9',
      '#5BAD6F': '2',
      '#E24A4A': '11',
      '#F5A623': '5',
      '#9B59B6': '3',
      '#E67E22': '6',
      '#95A5A6': '8',
    };
    return colorMap[hex] ?? '8';
  }

  // ── 캘린더 목록 조회 (✅ 페이징 처리) ─────────────
  Future<List<gcal.CalendarListEntry>> getCalendarList() async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);
      final result = <gcal.CalendarListEntry>[];
      String? pageToken;

      // ✅ nextPageToken 순회
      do {
        final response = await _withBackoff(
          () => api.calendarList.list(pageToken: pageToken),
        );
        result.addAll(response.items ?? []);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

      return result;
    } catch (e) {
      debugPrint('캘린더 목록 조회 오류: $e');
      return [];
    } finally {
      client?.close();
    }
  }

  // ── KIBO 캘린더만 조회 ────────────────────────────
  Future<List<gcal.CalendarListEntry>> getKiboCalendars() async {
    final list = await getCalendarList();
    return list
        .where((c) => c.summary?.startsWith('KIBO-') ?? false)
        .toList();
  }

  // ── 태그별 캘린더 ID 조회 또는 생성 ──────────────
  Future<String> getOrCreateCalendarId(String tag) async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);
      final calendarName = TagColors.calendarNameFor(tag);
      final colorHex = TagColors.colorFor(tag);

      // 기존 캘린더 찾기
      final list = await getCalendarList();
      for (final c in list) {
        if (c.summary == calendarName && c.id != null) {
          return c.id!;
        }
      }

      // 없으면 생성
      final created = await _withBackoff(
        () => api.calendars.insert(gcal.Calendar(summary: calendarName)),
      );

      if (created.id != null) {
        // 색상 적용
        await _withBackoff(
          () => api.calendarList.patch(
            gcal.CalendarListEntry(
              id: created.id,
              colorId: _hexToGoogleColorId(colorHex),
            ),
            created.id!,
          ),
        );
        debugPrint('캘린더 생성: $calendarName (${created.id})');
        return created.id!;
      }

      return 'primary';
    } catch (e) {
      debugPrint('캘린더 생성 오류: $e');
      return 'primary';
    } finally {
      client?.close();
    }
  }

  // ── 이벤트 추가 ───────────────────────────────────
  Future<String?> addEvent({
    required String title,
    required DateTime dateTime,
    String location = '',
    String description = '',
    List<String> tags = const [],
  }) async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);

      final calendarId = tags.isNotEmpty
          ? await getOrCreateCalendarId(tags.first)
          : 'primary';

      final tagsString = tags.map((t) => '#$t').join(' ');
      final fullTitle =
          tags.isNotEmpty ? '$title $tagsString' : title;

      // ✅ 기기 시간대 동적 적용
      final timeZone = _localTimeZone;

      final event = gcal.Event(
        summary: fullTitle,
        location: location.isNotEmpty ? location : null,
        description: description.isNotEmpty ? description : null,
        start: gcal.EventDateTime(
          dateTime: dateTime.toUtc(),
          timeZone: timeZone,
        ),
        end: gcal.EventDateTime(
          dateTime: dateTime.add(const Duration(hours: 1)).toUtc(),
          timeZone: timeZone,
        ),
      );

      final result = await _withBackoff(
        () => api.events.insert(event, calendarId),
      );

      debugPrint('이벤트 추가: ${result.id} → $calendarId');
      return result.id;
    } catch (e) {
      debugPrint('캘린더 추가 오류: $e');
      return null;
    } finally {
      client?.close();
    }
  }

  // ── 이벤트 삭제 ───────────────────────────────────
  Future<bool> deleteEvent(
    String googleEventId, {
    String calendarId = 'primary',
  }) async {
    if (googleEventId.isEmpty) return false;
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);
      await _withBackoff(
        () => api.events.delete(calendarId, googleEventId),
      );
      return true;
    } catch (e) {
      debugPrint('캘린더 삭제 오류: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  // ── 캘린더 삭제 + 일정 이동 (✅ 지수 백오프) ──────
  Future<bool> deleteCalendarAndMoveEvents({
    required String fromCalendarId,
    required String toTag,
  }) async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);
      final toCalendarId = await getOrCreateCalendarId(toTag);

      // ✅ 페이징으로 모든 이벤트 조회
      final allEvents = <gcal.Event>[];
      String? pageToken;
      do {
        final response = await _withBackoff(
          () => api.events.list(
            fromCalendarId,
            pageToken: pageToken,
          ),
        );
        allEvents.addAll(response.items ?? []);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

      // ✅ 10개마다 200ms 딜레이 — Rate Limit 방어
      for (int i = 0; i < allEvents.length; i++) {
        final event = allEvents[i];
        if (event.id == null) continue;

        await _withBackoff(
          () => api.events.move(
              fromCalendarId, event.id!, toCalendarId),
        );
        debugPrint('이벤트 이동: ${event.id} → $toCalendarId');

        if ((i + 1) % 10 == 0) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 캘린더 삭제
      await _withBackoff(
        () => api.calendars.delete(fromCalendarId),
      );
      debugPrint('캘린더 삭제 완료: $fromCalendarId');
      return true;
    } catch (e) {
      debugPrint('캘린더 삭제+이동 오류: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  // ── Google 캘린더 → KIBO 일정 가져오기 (✅ 페이징) ─
  Future<List<Map<String, dynamic>>> fetchEvents() async {
    http.Client? client;
    try {
      client = await _getAuthClient();
      final api = gcal.CalendarApi(client);
      final now = DateTime.now();

      final kiboCalendars = await getKiboCalendars();
      final calendarIds =
          kiboCalendars.map((c) => c.id!).toList();
      if (calendarIds.isEmpty) calendarIds.add('primary');

      final allEvents = <Map<String, dynamic>>[];

      for (final calendarId in calendarIds) {
        String? pageToken;

        // ✅ 페이징 처리
        do {
          final response = await _withBackoff(
            () => api.events.list(
              calendarId,
              timeMin:
                  now.subtract(const Duration(days: 7)).toUtc(),
              timeMax: now.add(const Duration(days: 7)).toUtc(),
              singleEvents: true,
              orderBy: 'startTime',
              pageToken: pageToken,
            ),
          );

          for (final e in response.items ?? []) {
            final DateTime start;
            if (e.start?.dateTime != null) {
              start = e.start!.dateTime!;
            } else if (e.start?.date != null) {
              final d = e.start!.date!;
              start = DateTime(d.year, d.month, d.day);
            } else {
              start = DateTime.now();
            }

            final summary = e.summary ?? '제목 없음';
            final tagRegex = RegExp(r'#(\w+)');
            final tags = tagRegex
                .allMatches(summary)
                .map((m) => m.group(1)!)
                .toList();
            final cleanTitle =
                summary.replaceAll(tagRegex, '').trim();

            allEvents.add({
              'title': cleanTitle,
              'date':
                  '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
              'time':
                  '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
              'location': e.location ?? '',
              'description': e.description ?? '',
              'googleEventId': e.id ?? '',
              'tags': tags,
            });
          }

          pageToken = response.nextPageToken;
        } while (pageToken != null);
      }

      return allEvents;
    } catch (e) {
      debugPrint('캘린더 가져오기 오류: $e');
      return [];
    } finally {
      client?.close();
    }
  }
}

// ── 인증 HTTP 클라이언트 래퍼 ─────────────────────────
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
  void close() => _inner.close();
}