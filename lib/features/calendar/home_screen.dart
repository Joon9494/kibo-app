import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../auth/auth_service.dart';
import '../../core/theme.dart';
import '../briefing/briefing_service.dart';
import '../lens/lens_screen.dart';
import 'gemini_service.dart';
import 'schedule_service.dart';
import 'schedule_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  void initState() {
    super.initState();

    // 음성 인식 초기화
    _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        debugPrint('음성 오류: $error');
      },
    ).then((available) {
      if (!mounted) return;
      setState(() => _speechAvailable = available);
    });

    // 스트림 한 번만 생성
    _schedulesStream = _scheduleService.getSchedules();
    _scheduleSubscription = _schedulesStream.listen(
      (schedules) {
        if (!mounted) return;
        setState(() => _schedules = schedules);
        _maybeUpdateBriefing(schedules);
      },
      onError: (error) {
        if (!mounted) return;
        debugPrint('스트림 오류: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정을 불러오는 중 오류가 발생했어요.'),
            backgroundColor: Colors.red,
          ),
        );
      },
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

    final text = await _briefingService.generateBriefing(schedules);

    if (!mounted) return;
    setState(() {
      _briefingText = text;
      _briefingLoading = false;
    });
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('음성 인식을 사용할 수 없어요. 마이크 권한을 확인해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
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
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          // 최종 결과면 자동 제출
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _onSubmit();
          }
        },
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() => _loading = true);

    final parsed = await _gemini.parseSchedule(input);
    if (parsed == null) {
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

    final success = await _scheduleService.saveSchedule(parsed);
    if (mounted) {
      if (success) {
        _controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${parsed['title']}" 일정이 추가됐어요!'),
            backgroundColor: KiboTheme.teal,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장 중 오류가 발생했어요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('KIBO',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: '렌즈로 일정 추가',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LensScreen()),
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
            // 인사말
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (user?.photoURL != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(user!.photoURL!),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    '안녕하세요, ${user?.displayName?.split(' ').first ?? ''}님!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // AI 브리핑 카드
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KiboTheme.navy.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: KiboTheme.navy.withOpacity(0.15),
                  ),
                ),
                child: _briefingLoading
                    ? const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('브리핑 생성 중...',
                              style: TextStyle(fontSize: 13)),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🤖', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _briefingText,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const Divider(height: 1),

            // 일정 목록
            Expanded(
              child: _schedules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '아직 일정이 없어요.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '아래에 자연어로 입력해보세요!',
                            style: TextStyle(
                                color: KiboTheme.teal, fontSize: 13),
                          ),
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
                              _scheduleService.deleteSchedule(s.id),
                        );
                      },
                    ),
            ),

            // 하단 입력창
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '내일 오후 3시 강남역 미팅',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _onSubmit(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 마이크 버튼
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Colors.grey,
                      ),
                      onPressed: _toggleListening,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 전송 버튼
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(Icons.send, color: KiboTheme.blue),
                            onPressed: _onSubmit,
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

class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onDelete;

  const _ScheduleCard({required this.schedule, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dt = schedule.dateTime;
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[dt.weekday - 1];
    final dateStr =
        '${dt.year}년 ${dt.month}월 ${dt.day}일 ($weekday) '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: KiboTheme.navy.withOpacity(0.08),
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
                  color: KiboTheme.navy,
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (schedule.location.isNotEmpty)
              Text(
                '📍 ${schedule.location}',
                style: TextStyle(fontSize: 12, color: KiboTheme.teal),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
          onPressed: onDelete,
        ),
      ),
    );
  }
}