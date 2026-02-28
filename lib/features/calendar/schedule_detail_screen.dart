// =====================================================
// 📁 lib/features/calendar/schedule_detail_screen.dart
// 역할: 일정 상세 화면
//       일정 정보 표시, 출발 추천, 이동 추적, 도착 기록
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'schedule_model.dart';
import 'schedule_service.dart';
import '../arrival/arrival_tracking_service.dart';
import '../arrival/punctuality_service.dart';

class ScheduleDetailScreen extends ConsumerStatefulWidget {
  final Schedule schedule;

  const ScheduleDetailScreen({super.key, required this.schedule});

  @override
  ConsumerState<ScheduleDetailScreen> createState() =>
      _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState
    extends ConsumerState<ScheduleDetailScreen> {
  final _scheduleService = ScheduleService();

  DepartureInfo? _departureInfo;
  bool _loadingDeparture = false;
  String? _departureError;

  @override
  void initState() {
    super.initState();
    _loadDepartureInfo();
  }

  // ── 출발 정보 로드 ────────────────────────────────
  Future<void> _loadDepartureInfo() async {
    final schedule = widget.schedule;

    // 장소 없거나 과거 일정이면 건너뜀
    if (schedule.location.isEmpty) return;
    if (schedule.dateTime.isBefore(DateTime.now())) return;

    // 1) 이미 계산된 정보가 state에 있는지 확인
    final trackingState = ref.read(arrivalTrackingProvider);
    final existing = trackingState.todayAlarms
        .where((a) => a.scheduleId == schedule.id)
        .firstOrNull;

    if (existing != null) {
      setState(() => _departureInfo = existing);
      return;
    }

    // 2) 없으면 새로 계산
    setState(() => _loadingDeparture = true);

    try {
      final info = await ref
          .read(arrivalTrackingProvider.notifier)
          .setupDepartureAlarm(schedule: schedule);

      if (!mounted) return;
      setState(() {
        _departureInfo = info;
        _loadingDeparture = false;
        if (info == null && schedule.location.isNotEmpty) {
          _departureError = '경로를 계산할 수 없어요. 위치 권한을 확인해주세요.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDeparture = false;
        _departureError = '출발 정보를 가져오지 못했어요.';
      });
    }
  }

  // ── 삭제 확인 다이얼로그 ──────────────────────────
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"${widget.schedule.title}" 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success =
          await _scheduleService.deleteSchedule(widget.schedule);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(); // 상세 화면 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 일정이 삭제됐어요.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제 중 오류가 발생했어요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── 출발 시작 ─────────────────────────────────────
  Future<void> _startTraveling() async {
    if (_departureInfo == null) return;

    await ref.read(arrivalTrackingProvider.notifier).startTraveling(
          schedule: widget.schedule,
          destLat: _departureInfo!.destLat,
          destLng: _departureInfo!.destLng,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🚀 이동 추적을 시작합니다!')),
    );
  }

  // ── 수동 도착 처리 ────────────────────────────────
  Future<void> _markAsArrived() async {
    await ref
        .read(arrivalTrackingProvider.notifier)
        .markAsArrived(widget.schedule);

    // 지각 패턴 재학습
    await ref.read(punctualityProvider.notifier).recalculateProfile();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 도착이 기록됐어요!')),
    );
  }

  // ── 추적 중지 ─────────────────────────────────────
  void _stopTracking() {
    ref.read(arrivalTrackingProvider.notifier).stopTracking();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('추적이 중지됐어요.')),
    );
  }

  // ── 색상 변환 헬퍼 ────────────────────────────────
  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final colorScheme = Theme.of(context).colorScheme;
    final trackingState = ref.watch(arrivalTrackingProvider);

    // 이 일정이 현재 추적 중인지 확인
    final isActiveTracking =
        trackingState.activeScheduleId == schedule.id &&
            trackingState.isTracking;
    final isArrived = schedule.isArrived ||
        (trackingState.activeScheduleId == schedule.id &&
            trackingState.status == TrackingStatus.arrived);

    final dt = schedule.dateTime;
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[dt.weekday - 1];
    final isPast = dt.isBefore(DateTime.now());

    final tagColor = schedule.tags.isNotEmpty
        ? _hexToColor(TagColors.colorFor(schedule.tags.first))
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 상세'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 제목 ────────────────────────────────
            Text(
              schedule.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // ── 날짜/시간 ───────────────────────────
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              iconColor: colorScheme.primary,
              text: '${dt.year}년 ${dt.month}월 ${dt.day}일 ($weekday)',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.access_time_outlined,
              iconColor: colorScheme.primary,
              text:
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
            ),

            // ── 장소 ────────────────────────────────
            if (schedule.location.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.location_on_outlined,
                iconColor: colorScheme.secondary,
                text: schedule.location,
              ),
            ],

            // ── 교통수단 ────────────────────────────
            if (schedule.transportMode != TransportMode.unknown) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.directions_outlined,
                iconColor: Colors.orange,
                text:
                    '${schedule.transportMode.emoji} ${schedule.transportMode.label}',
              ),
            ],

            // ── 동행 ────────────────────────────────
            if (schedule.companions.isNotEmpty &&
                schedule.companions != '혼자') ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.people_outline,
                iconColor: Colors.purple,
                text: schedule.companions,
              ),
            ],

            // ── 태그 ────────────────────────────────
            if (schedule.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: schedule.tags.map((tag) {
                  final color = _hexToColor(TagColors.colorFor(tag));
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // ── 설명 ────────────────────────────────
            if (schedule.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  schedule.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ══════════════════════════════════════════
            // 8단계: 출발 추천 카드
            // ══════════════════════════════════════════

            if (schedule.location.isNotEmpty && !isPast && !isArrived)
              _buildDepartureCard(colorScheme),

            // ══════════════════════════════════════════
            // 8단계: 이동 추적 상태
            // ══════════════════════════════════════════

            if (isActiveTracking)
              _buildTrackingCard(trackingState, colorScheme),

            // ══════════════════════════════════════════
            // 도착 완료 표시
            // ══════════════════════════════════════════

            if (isArrived) _buildArrivedCard(colorScheme),

            const SizedBox(height: 32),
          ],
        ),
      ),

      // ── 하단 액션 버튼 ────────────────────────────
      bottomNavigationBar: _buildBottomBar(
        colorScheme: colorScheme,
        isActiveTracking: isActiveTracking,
        isArrived: isArrived,
        isPast: isPast,
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 출발 추천 카드
  // ══════════════════════════════════════════════════

  Widget _buildDepartureCard(ColorScheme colorScheme) {
    if (_loadingDeparture) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text('경로 계산 중...',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    if (_departureError != null && _departureInfo == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _departureError!,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_departureInfo == null) return const SizedBox.shrink();

    final info = _departureInfo!;
    final depH =
        info.recommendedDeparture.hour.toString().padLeft(2, '0');
    final depM =
        info.recommendedDeparture.minute.toString().padLeft(2, '0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(info.transportMode.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('출발 추천',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),

            // 출발 시각
            Row(
              children: [
                Icon(Icons.departure_board_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '$depH:$depM 출발 추천',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 소요시간 + 여유시간
            Row(
              children: [
                _MiniChip(
                  icon: Icons.timer_outlined,
                  text: '이동 ${info.estimatedMinutes}분',
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _MiniChip(
                  icon: Icons.shield_outlined,
                  text: '여유 ${info.bufferMinutes}분',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 상태 메시지
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.departureMessage,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 이동 추적 카드
  // ══════════════════════════════════════════════════

  Widget _buildTrackingCard(
      ArrivalTrackingState state, ColorScheme colorScheme) {
    final distanceKm = state.distanceToDestination != null
        ? (state.distanceToDestination! / 1000).toStringAsFixed(1)
        : '?';
    final remainingMin = state.latestRouteMinutes;

    final statusText = state.status == TrackingStatus.nearDestination
        ? '🎯 목적지 근처예요!'
        : '🚀 이동 중';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusText,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniChip(
                    icon: Icons.straighten_outlined,
                    text: '남은 거리 ${distanceKm}km',
                    color: Colors.blue,
                  ),
                  if (remainingMin != null) ...[
                    const SizedBox(width: 8),
                    _MiniChip(
                      icon: Icons.timer_outlined,
                      text: '약 ${remainingMin}분',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _stopTracking,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: const Text('추적 중지'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _markAsArrived,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('도착 확인'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 도착 완료 카드
  // ══════════════════════════════════════════════════

  Widget _buildArrivedCard(ColorScheme colorScheme) {
    final schedule = widget.schedule;
    final lateMin = schedule.lateMinutes ?? 0;
    final isLate = lateMin > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Card(
        color: isLate
            ? Colors.orange.shade50
            : Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                isLate ? '⏰' : '🎉',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLate ? '${lateMin}분 늦게 도착' : '정시 도착!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isLate ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                    if (schedule.actualArrivalTime != null)
                      Text(
                        '도착 시각: ${_formatTime(schedule.actualArrivalTime!)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 하단 바
  // ══════════════════════════════════════════════════

  Widget? _buildBottomBar({
    required ColorScheme colorScheme,
    required bool isActiveTracking,
    required bool isArrived,
    required bool isPast,
  }) {
    // 이미 추적 중이거나 도착했으면 하단 바 숨김
    if (isActiveTracking || isArrived) return null;

    // 장소 있고, 미래 일정이고, 출발 정보 있으면 "출발하기" 버튼
    if (widget.schedule.location.isNotEmpty &&
        !isPast &&
        _departureInfo != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _startTraveling,
              icon: Text(_departureInfo!.transportMode.emoji,
                  style: const TextStyle(fontSize: 18)),
              label: const Text('출발하기',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );
    }

    return null;
  }

  // ── 유틸 ──────────────────────────────────────────
  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════
// 공용 위젯
// ══════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
