// =====================================================
// 📁 lib/features/settings/calendar_manage_screen.dart
// =====================================================

import 'package:flutter/material.dart';
import '../calendar/google_calendar_service.dart';
import '../calendar/schedule_model.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

class CalendarManageScreen extends StatefulWidget {
  // ✅ nullable — State에서 기본값 처리
  final GoogleCalendarService? calendarService;

  const CalendarManageScreen({super.key, this.calendarService});

  @override
  State<CalendarManageScreen> createState() =>
      _CalendarManageScreenState();
}

class _CalendarManageScreenState
    extends State<CalendarManageScreen> {
  late final GoogleCalendarService _calendarService;
  List<gcal.CalendarListEntry> _kiboCalendars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // ✅ nullable이면 기본 인스턴스 사용
    _calendarService =
        widget.calendarService ?? GoogleCalendarService();
    _loadCalendars();
  }

  // ── 스낵바 헬퍼 ───────────────────────────────────
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ── 캘린더 목록 로드 ──────────────────────────────
  Future<void> _loadCalendars() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _calendarService.getKiboCalendars();
      if (!mounted) return;
      setState(() {
        _kiboCalendars = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('캘린더 목록을 불러오지 못했어요: $e', isError: true);
    }
  }

  // ── 캘린더 추가 다이얼로그 ────────────────────────
  Future<void> _showAddCalendarDialog() async {
    final controller = TextEditingController();
    String selectedColor = '#95A5A6';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('캘린더 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '태그명',
                  hintText: '예: 헬스, 스터디, 취미',
                ),
              ),
              const SizedBox(height: 16),
              const Text('색상 선택', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TagColors.defaults.entries.map((entry) {
                  final hex = entry.value;
                  final isSelected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () =>
                        setStateDialog(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _hexToColor(hex),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final tag = controller.text.trim();
                if (tag.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (!mounted) return;
                  setState(() => _loading = true);
                  await _calendarService.getOrCreateCalendarId(tag);
                  await _loadCalendars();
                  _showSnackBar('✅ $tag 캘린더가 추가됐어요!');
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _loading = false);
                  _showSnackBar('캘린더 추가 실패: $e', isError: true);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 캘린더 삭제 다이얼로그 ────────────────────────
  Future<void> _showDeleteCalendarDialog(
      gcal.CalendarListEntry calendar) async {
    String targetTag = _kiboCalendars
            .where((c) => c.id != calendar.id)
            .firstOrNull
            ?.summary
            ?.replaceFirst('KIBO-', '') ??
        '기타';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('캘린더 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${calendar.summary}"의 일정을\n어느 캘린더로 이동할까요?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ..._kiboCalendars
                  .where((c) => c.id != calendar.id)
                  .map((c) {
                final tag =
                    c.summary?.replaceFirst('KIBO-', '') ?? '기타';
                return RadioListTile<String>(
                  title: Text(tag),
                  value: tag,
                  groupValue: targetTag,
                  onChanged: (v) =>
                      setStateDialog(() => targetTag = v ?? '기타'),
                );
              }),
              RadioListTile<String>(
                title: const Text('일정도 함께 삭제',
                    style: TextStyle(color: Colors.red)),
                value: '__delete__',
                groupValue: targetTag,
                onChanged: (v) =>
                    setStateDialog(() => targetTag = v ?? '기타'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  if (!mounted) return;
                  setState(() => _loading = true);
                  final toTag =
                      targetTag == '__delete__' ? '기타' : targetTag;
                  await _calendarService.deleteCalendarAndMoveEvents(
                    fromCalendarId: calendar.id!,
                    toTag: toTag,
                  );
                  await _loadCalendars();
                  _showSnackBar(
                    targetTag == '__delete__'
                        ? '✅ 캘린더와 일정이 삭제됐어요.'
                        : '✅ 일정이 $targetTag 캘린더로 이동됐어요.',
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _loading = false);
                  _showSnackBar('캘린더 삭제 실패: $e', isError: true);
                }
              },
              child: const Text('삭제',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendars,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    '태그별 Google 캘린더가 자동으로 생성돼요.\n'
                    '일정 등록 시 태그를 추가하면 해당 캘린더에 저장됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('기본 태그',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TagColors.defaults.entries.map((entry) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: _hexToColor(entry.value),
                        radius: 8,
                      ),
                      label: Text('#${entry.key}'),
                      labelStyle: const TextStyle(fontSize: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Google 캘린더 목록',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    )),
                const SizedBox(height: 8),
                if (_kiboCalendars.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        '아직 생성된 KIBO 캘린더가 없어요.\n'
                        '일정에 태그를 추가하면 자동으로 생성돼요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                else
                  ..._kiboCalendars.map((calendar) {
                    final tag =
                        calendar.summary?.replaceFirst('KIBO-', '') ?? '';
                    final colorHex = TagColors.colorFor(tag);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _hexToColor(colorHex),
                          radius: 16,
                          child: Text(
                            tag.isNotEmpty ? tag[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('#$tag',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          calendar.summary ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Colors.grey.shade400),
                          onPressed: () =>
                              _showDeleteCalendarDialog(calendar),
                        ),
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCalendarDialog,
        icon: const Icon(Icons.add),
        label: const Text('캘린더 추가'),
      ),
    );
  }
}