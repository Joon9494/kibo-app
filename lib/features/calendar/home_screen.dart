// =====================================================
// 📁 lib/features/calendar/home_screen.dart
// =====================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../auth/auth_service.dart';
import '../briefing/briefing_service.dart';
import '../lens/lens_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/theme_provider.dart';
import 'gemini_service.dart';
import 'schedule_service.dart';
import 'schedule_model.dart';
import 'schedule_detail_screen.dart';
// ✅ 8단계: 도착 추적 서비스
import '../arrival/arrival_tracking_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _gemini = GeminiService();
  final _scheduleService = ScheduleService();
  final _briefingService = BriefingService();
  final _controller = TextEditingController();
  final _speech = SpeechToText();

  late final Stream<List<Schedule>> _schedulesStream;
  StreamSubscription<List<Schedule>>? _scheduleSubscription;

  List<Schedule> _schedules = [];
  bool _loading = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _briefingText = '브리핑을 불러오는 중...';
  bool _briefingLoading = true;
  List<String> _lastScheduleIds = ['__initial__'];

  // ✅ 대화형 입력 상태
  ParseResult? _pendingParseResult;
  Map<String, dynamic> _pendingData = {};

  // ✅ 디바운싱용 타이머
  Timer? _briefingDebounceTimer;

  // ✅ 8단계: 출발 알람 중복 설정 방지 플래그
  bool _arrivalAlarmsSetup = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();

    _schedulesStream = _scheduleService.getSchedules();
    _scheduleSubscription = _schedulesStream.listen(
      (schedules) {
        if (!mounted) return;
        setState(() => _schedules = schedules);
        _debouncedUpdateBriefing(schedules);

        // ✅ 8단계: 오늘 일정 출발 알람 일괄 설정 (최초 1회)
        if (!_arrivalAlarmsSetup && schedules.isNotEmpty) {
          _arrivalAlarmsSetup = true;
          Future.microtask(() {
            ref
                .read(arrivalTrackingProvider.notifier)
                .setupTodayAlarms(schedules);
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정을 불러오는 중 오류가 발생했어요.'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  // ── 음성 인식 초기화 ──────────────────────────────
  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  // ── ✅ 디바운싱 브리핑 업데이트 (500ms) ───────────
  void _debouncedUpdateBriefing(List<Schedule> schedules) {
    _briefingDebounceTimer?.cancel();
    _briefingDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _maybeUpdateBriefing(schedules),
    );
  }

  Future<void> _maybeUpdateBriefing(List<Schedule> schedules) async {
    final today = DateTime.now();
    final todaySchedules = schedules.where((s) {
      return s.dateTime.year == today.year &&
          s.dateTime.month == today.month &&
          s.dateTime.day == today.day;
    }).toList();

    final newIds = todaySchedules.map((s) => s.id).toList();
    if (_lastScheduleIds.join() == newIds.join()) return;
    _lastScheduleIds = newIds;

    if (!mounted) return;
    setState(() => _briefingLoading = true);

    final userPrompt = ref.read(briefingPromptProvider);
    final text = await _briefingService.generateBriefing(
      schedules,
      userPrompt: userPrompt,
    );

    // ✅ 비동기 완료 후 mounted 재검사
    if (!mounted) return;
    setState(() {
      _briefingText = text;
      _briefingLoading = false;
    });
  }

  Future<void> _forcedRefreshBriefing() async {
    if (!mounted) return;
    setState(() => _briefingLoading = true);

    final userPrompt = ref.read(briefingPromptProvider);
    final text = await _briefingService.generateBriefing(
      _schedules,
      userPrompt: userPrompt,
    );

    // ✅ 비동기 완료 후 mounted 재검사
    if (!mounted) return;
    setState(() {
      _briefingText = text;
      _briefingLoading = false;
      _lastScheduleIds = _schedules
          .where((s) {
            final today = DateTime.now();
            return s.dateTime.year == today.year &&
                s.dateTime.month == today.month &&
                s.dateTime.day == today.day;
          })
          .map((s) => s.id)
          .toList();
    });
  }

  // ── ✅ 음성 인식 권한 처리 ─────────────────────────
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      // ✅ 권한 상태 확인
      final status = await Permission.microphone.status;

      if (status.isPermanentlyDenied) {
        // 영구 거부 → 설정으로 유도
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('마이크 권한 필요'),
            content: const Text(
              '음성 인식을 사용하려면 마이크 권한이 필요해요.\n'
              '설정 앱에서 권한을 허용해주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings(); // ✅ 설정 앱으로 이동
                },
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('마이크 권한을 허용해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    } else {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _isListening = true);

      // ✅ 기기 로케일 동적 적용
      final locales = await _speech.locales();
      final deviceLocale = locales
          .where((l) =>
              l.localeId.startsWith(
                  WidgetsBinding.instance.platformDispatcher.locale
                      .languageCode))
          .firstOrNull;
      final localeId = deviceLocale?.localeId ?? 'ko_KR';

      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          if (result.finalResult &&
              result.recognizedWords.isNotEmpty) {
            _onSubmit();
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  // ── 일정 입력 제출 ────────────────────────────────
  Future<void> _onSubmit() async {
    if (_loading) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() => _loading = true);

    final result = await _gemini.parseScheduleWithFollowUp(input);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정을 이해하지 못했어요. 다시 입력해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _loading = false);
      return;
    }

    _controller.clear();
    setState(() => _loading = false);

    if (result.isComplete) {
      await _saveSchedule(result.data);
    } else {
      setState(() {
        _pendingParseResult = result;
        _pendingData = Map.from(result.data);
      });
    }
  }

  // ── 추가 질문 답변 처리 ───────────────────────────
  void _onFollowUpAnswer(String field, String answer) {
    setState(() {
      switch (field) {
        case 'transportMode':
          final map = {
            '자동차': 'car',
            '대중교통': 'transit',
            '도보': 'walk',
            '자전거': 'bicycle',
          };
          _pendingData['transportMode'] = map[answer] ?? 'unknown';
          break;
        case 'companions':
          _pendingData['companions'] = answer;
          break;
        case 'tags':
          _pendingData['tags'] = [answer];
          break;
      }
    });
  }

  // ── 최종 저장 ─────────────────────────────────────
  Future<void> _saveSchedule(Map<String, dynamic> data) async {
    setState(() {
      _pendingParseResult = null;
      _pendingData = {};
      _loading = true;
    });

    final tags = List<String>.from(data['tags'] ?? []);
    data['title'] = GeminiService.addEmoji(
      data['title']?.toString() ?? '새 일정',
      tags,
    );

    final success = await _scheduleService.saveSchedule(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '✅ "${data['title']}" 일정이 추가됐어요!'
            : '저장 중 오류가 발생했어요.'),
        backgroundColor:
            success ? Theme.of(context).colorScheme.primary : Colors.red,
      ),
    );
    setState(() => _loading = false);
  }

  // ── 사진으로 일정 추가 안내 바텀시트 ──────────────
  void _showLensGuide() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📷 사진으로 일정 추가',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              '청첩장, 공연 티켓, 명함 등 사진을 찍으면\nAI가 자동으로 일정을 추출해요.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            const _LensExampleChip(label: '청첩장 📮'),
            const _LensExampleChip(label: '공연 티켓 🎟️'),
            const _LensExampleChip(label: '병원 예약 확인증 🏥'),
            const _LensExampleChip(label: '명함 💼'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('사진 찍어서 일정 추가하기'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LensScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _briefingDebounceTimer?.cancel(); // ✅ 타이머 해제
    _scheduleSubscription?.cancel();
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final isKeyboardVisible =
        MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('KIBO',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (user?.photoURL != null)
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            NetworkImage(user!.photoURL!),
                      ),
                    const SizedBox(width: 12),
                    Text(
                      '안녕하세요, ${user?.displayName?.split(' ').first ?? ''}님!',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AI 브리핑',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                          letterSpacing: 0.3,
                        )),
                    _briefingLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary
                                  .withOpacity(0.6),
                            ),
                          )
                        : GestureDetector(
                            onTap: _forcedRefreshBriefing,
                            child: Row(
                              children: [
                                Icon(Icons.refresh,
                                    size: 15,
                                    color: colorScheme.primary
                                        .withOpacity(0.6)),
                                const SizedBox(width: 2),
                                Text('새로고침',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.primary
                                            .withOpacity(0.6))),
                              ],
                            ),
                          ),
                  ],
                ),
              ),

            if (!isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          colorScheme.primary.withOpacity(0.15),
                    ),
                  ),
                  child: _briefingLoading
                      ? Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('브리핑 생성 중...',
                                style: TextStyle(fontSize: 13)),
                          ],
                        )
                      : Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('🤖',
                                style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_briefingText,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5)),
                            ),
                          ],
                        ),
                ),
              ),

            const Divider(height: 1),

            if (_pendingParseResult != null)
              _FollowUpCard(
                parseResult: _pendingParseResult!,
                pendingData: _pendingData,
                onAnswer: _onFollowUpAnswer,
                onSave: () => _saveSchedule(_pendingData),
                onCancel: () => setState(() {
                  _pendingParseResult = null;
                  _pendingData = {};
                }),
              ),

            Expanded(
              child: _schedules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 48,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('아직 일정이 없어요.',
                              style: TextStyle(
                                  color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          Text('아래에 자연어로 입력해보세요!',
                              style: TextStyle(
                                  color: colorScheme.secondary,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final s = _schedules[index];
                        return _ScheduleCard(
                          schedule: s,
                          onDelete: () =>
                              _scheduleService.deleteSchedule(s),
                          // ✅ 8단계: 일정 카드 탭 → 상세 화면 이동
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ScheduleDetailScreen(schedule: s),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Container(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: '내일 오후 3시 강남역 미팅',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12),
                          ),
                          onSubmitted: (_) => _onSubmit(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: Icon(
                            _isListening
                                ? Icons.mic
                                : Icons.mic_none,
                            color: _isListening
                                ? Colors.red
                                : Colors.grey,
                          ),
                          onPressed: _toggleListening,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: _loading
                            ? Padding(
                                padding:
                                    const EdgeInsets.all(12),
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.send,
                                    color:
                                        colorScheme.primary),
                                onPressed: _onSubmit,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showLensGuide,
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 16,
                            color: colorScheme.primary
                                .withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          '청첩장·티켓·명함 사진으로 일정 추가',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 대화형 질문 카드 ──────────────────────────────────
class _FollowUpCard extends StatelessWidget {
  final ParseResult parseResult;
  final Map<String, dynamic> pendingData;
  final Function(String field, String answer) onAnswer;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _FollowUpCard({
    required this.parseResult,
    required this.pendingData,
    required this.onAnswer,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = parseResult.data['title'] ?? '새 일정';
    final date = parseResult.data['date'] ?? '';
    final time = parseResult.data['time'] ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$title · $date $time',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onCancel,
                child: Icon(Icons.close,
                    size: 18, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...parseResult.questions.map((q) {
            final answered = pendingData[q.field] != null &&
                pendingData[q.field].toString().isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...q.options.map((option) {
                        final isSelected = _isSelected(
                            q.field, option, pendingData);
                        return GestureDetector(
                          onTap: () =>
                              onAnswer(q.field, option),
                          child: AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 150),
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(option,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                )),
                          ),
                        );
                      }),
                      if (q.skippable)
                        GestureDetector(
                          onTap: () => onAnswer(q.field, ''),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      Colors.grey.shade200),
                            ),
                            child: Text('건너뛰기',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey.shade500)),
                          ),
                        ),
                    ],
                  ),
                  if (answered)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 12,
                              color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text('선택됨',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.primary)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              child: const Text('일정 저장하기'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(
      String field, String option, Map<String, dynamic> data) {
    final value = data[field]?.toString() ?? '';
    const map = {
      '자동차': 'car',
      '대중교통': 'transit',
      '도보': 'walk',
      '자전거': 'bicycle',
    };
    if (field == 'transportMode') {
      return value == (map[option] ?? option);
    }
    if (field == 'tags') {
      final tags = data['tags'];
      if (tags is List) return tags.contains(option);
    }
    return value == option;
  }
}

// ── 렌즈 예시 칩 ──────────────────────────────────────
class _LensExampleChip extends StatelessWidget {
  final String label;
  const _LensExampleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ── 일정 카드 ─────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onDelete;
  final VoidCallback? onTap; // ✅ 8단계: 탭 콜백 추가

  const _ScheduleCard({
    required this.schedule,
    required this.onDelete,
    this.onTap,
  });

  // ✅ _hexToColor 함수
  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final dt = schedule.dateTime;
    final colorScheme = Theme.of(context).colorScheme;
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[dt.weekday - 1];
    final dateStr =
        '${dt.year}년 ${dt.month}월 ${dt.day}일 ($weekday) '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';

    final tagColor = schedule.tags.isNotEmpty
        ? _hexToColor(TagColors.colorFor(schedule.tags.first))
        : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap, // ✅ 8단계: 탭 시 상세 화면 이동
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dt.month}/${dt.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tagColor,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          schedule.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            if (schedule.location.isNotEmpty)
              Text(
                '📍 ${schedule.location}',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.secondary),
              ),
            if (schedule.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: 4,
                  children: schedule.tags.map((tag) {
                    final color =
                        _hexToColor(TagColors.colorFor(tag));
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.grey.shade400,
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
