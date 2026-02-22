import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../../core/theme.dart';
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
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _onSubmit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() => _loading = true);
    final parsed = await _gemini.parseSchedule(input);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정을 이해하지 못했어요. 다시 입력해주세요.'), backgroundColor: Colors.orange),
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
          SnackBar(content: Text('✅ "${parsed['title']}" 일정이 추가됐어요!'), backgroundColor: KiboTheme.teal),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요.'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KIBO', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => AuthService().signOut()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (user?.photoURL != null)
                  CircleAvatar(radius: 20, backgroundImage: NetworkImage(user!.photoURL!)),
                const SizedBox(width: 12),
                Text('안녕하세요, ${user?.displayName?.split(' ').first ?? ''}님!',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Schedule>>(
              stream: _scheduleService.getSchedules(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final schedules = snapshot.data ?? [];
                if (schedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('아직 일정이 없어요.', style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        Text('아래에 자연어로 입력해보세요!', style: TextStyle(color: KiboTheme.teal, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final s = schedules[index];
                    return _ScheduleCard(schedule: s, onDelete: () => _scheduleService.deleteSchedule(s.id));
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '내일 오후 3시 강남역 미팅',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48, height: 48,
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(icon: Icon(Icons.send, color: KiboTheme.blue), onPressed: _onSubmit),
              ),
            ],
          ),
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
    final dateStr = '${dt.year}년 ${dt.month}월 ${dt.day}일 ($weekday) ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: KiboTheme.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [Text('${dt.month}/${dt.day}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: KiboTheme.navy))]),
        ),
        title: Text(schedule.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (schedule.location.isNotEmpty)
              Text('📍 ${schedule.location}', style: TextStyle(fontSize: 12, color: KiboTheme.teal)),
          ],
        ),
        trailing: IconButton(icon: Icon(Icons.delete_outline, color: Colors.grey.shade400), onPressed: onDelete),
      ),
    );
  }
}
