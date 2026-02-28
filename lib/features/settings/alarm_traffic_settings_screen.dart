// =====================================================
// 📁 lib/features/settings/alarm_traffic_settings_screen.dart
// 역할: 교통 예측 알람 · 이동 추적 · 여유시간 설정
//       기존 arrival_settings_section 내용을 독립 화면으로 승격
//       "기본 여유시간"에 대한 친절한 설명 포함
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../arrival/punctuality_service.dart';

// ── 설정 Provider ────────────────────────────────────
final arrivalSettingsProvider =
    StateNotifierProvider<ArrivalSettingsNotifier, ArrivalSettings>(
  (ref) => ArrivalSettingsNotifier(),
);

class ArrivalSettings {
  final bool trafficAlarmEnabled;
  final bool locationTrackingEnabled;
  final bool punctualityLearning;
  final int defaultBufferMinutes;

  const ArrivalSettings({
    this.trafficAlarmEnabled = true,
    this.locationTrackingEnabled = true,
    this.punctualityLearning = true,
    this.defaultBufferMinutes = 10,
  });

  ArrivalSettings copyWith({
    bool? trafficAlarmEnabled,
    bool? locationTrackingEnabled,
    bool? punctualityLearning,
    int? defaultBufferMinutes,
  }) {
    return ArrivalSettings(
      trafficAlarmEnabled:
          trafficAlarmEnabled ?? this.trafficAlarmEnabled,
      locationTrackingEnabled:
          locationTrackingEnabled ?? this.locationTrackingEnabled,
      punctualityLearning:
          punctualityLearning ?? this.punctualityLearning,
      defaultBufferMinutes:
          defaultBufferMinutes ?? this.defaultBufferMinutes,
    );
  }
}

class ArrivalSettingsNotifier extends StateNotifier<ArrivalSettings> {
  ArrivalSettingsNotifier() : super(const ArrivalSettings());

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = ArrivalSettings(
      trafficAlarmEnabled:
          prefs.getBool('arrival_traffic_alarm') ?? true,
      locationTrackingEnabled:
          prefs.getBool('arrival_location_tracking') ?? true,
      punctualityLearning:
          prefs.getBool('arrival_punctuality_learning') ?? true,
      defaultBufferMinutes:
          prefs.getInt('arrival_buffer_minutes') ?? 10,
    );
  }

  Future<void> setTrafficAlarm(bool v) async {
    state = state.copyWith(trafficAlarmEnabled: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arrival_traffic_alarm', v);
  }

  Future<void> setLocationTracking(bool v) async {
    state = state.copyWith(locationTrackingEnabled: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arrival_location_tracking', v);
  }

  Future<void> setPunctualityLearning(bool v) async {
    state = state.copyWith(punctualityLearning: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('arrival_punctuality_learning', v);
  }

  Future<void> setBufferMinutes(int min) async {
    state = state.copyWith(defaultBufferMinutes: min);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('arrival_buffer_minutes', min);
  }
}

// ── 메인 화면 ────────────────────────────────────────

class AlarmTrafficSettingsScreen extends ConsumerStatefulWidget {
  const AlarmTrafficSettingsScreen({super.key});

  @override
  ConsumerState<AlarmTrafficSettingsScreen> createState() =>
      _AlarmTrafficSettingsScreenState();
}

class _AlarmTrafficSettingsScreenState
    extends ConsumerState<AlarmTrafficSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(arrivalSettingsProvider.notifier).loadSettings();
      ref.read(punctualityProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(arrivalSettingsProvider);
    final punctuality = ref.watch(punctualityProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('알람 및 교통')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 토글 설정들 ────────────────────────────
          Card(
            child: Column(
              children: [
                // 교통 예측 알람
                SwitchListTile.adaptive(
                  secondary: _SettingIcon(
                    icon: Icons.notifications_active_outlined,
                    color: Colors.orange,
                  ),
                  title: const Text('교통 예측 알람',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '이동 시간을 고려해 출발 시각에 알림을 보내요.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  value: settings.trafficAlarmEnabled,
                  onChanged: (v) => ref
                      .read(arrivalSettingsProvider.notifier)
                      .setTrafficAlarm(v),
                ),

                _divider(),

                // 이동 중 위치 추적
                SwitchListTile.adaptive(
                  secondary: _SettingIcon(
                    icon: Icons.location_on_outlined,
                    color: Colors.blue,
                  ),
                  title: const Text('이동 중 위치 추적',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '이동 중 남은 거리와 시간을 실시간으로 알려줘요.\n'
                    '목적지 200m 이내 도착 시 자동 감지해요.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  value: settings.locationTrackingEnabled,
                  onChanged: (v) => ref
                      .read(arrivalSettingsProvider.notifier)
                      .setLocationTracking(v),
                ),

                _divider(),

                // 지각 패턴 학습
                SwitchListTile.adaptive(
                  secondary: _SettingIcon(
                    icon: Icons.psychology_outlined,
                    color: Colors.purple,
                  ),
                  title: const Text('지각 패턴 학습',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _punctualitySubtitle(punctuality.profile),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  value: settings.punctualityLearning,
                  onChanged: (v) => ref
                      .read(arrivalSettingsProvider.notifier)
                      .setPunctualityLearning(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 기본 여유시간 (자세한 설명 포함) ───────
          Text('기본 여유시간',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          // 설명 카드
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '여유시간이란?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '출발 알림을 보낼 때, 이동 시간 외에 추가로 확보하는 '
                  '시간이에요.\n\n'
                  '예를 들어 이동 시간이 30분이고 여유시간이 10분이면,\n'
                  '일정 시작 40분 전에 "지금 출발하세요!" 알림이 와요.\n\n'
                  '주차 시간, 건물 진입, 엘리베이터 등 이동 시간에 '
                  '포함되지 않는 시간을 대비해요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 여유시간 선택 카드
          Card(
            child: Column(
              children: [5, 10, 15, 20, 30].map((min) {
                final isSelected = settings.defaultBufferMinutes == min;
                return ListTile(
                  leading: _SettingIcon(
                    icon: Icons.timer_outlined,
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                  title: Text(
                    '$min분',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                  subtitle: Text(
                    _bufferDescription(min),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                          color: colorScheme.primary, size: 20)
                      : Icon(Icons.circle_outlined,
                          color: Colors.grey.shade300, size: 20),
                  onTap: () => ref
                      .read(arrivalSettingsProvider.notifier)
                      .setBufferMinutes(min),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ── 지각 패턴 카드 (5회 이상 데이터 후) ────
          if (punctuality.profile != null &&
              punctuality.profile!.totalTrips >= 5) ...[
            Text('나의 시간 관리',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 8),
            _PunctualityCard(profile: punctuality.profile!),
          ],
        ],
      ),
    );
  }

  String _punctualitySubtitle(PunctualityProfile? profile) {
    if (profile == null || profile.totalTrips < 5) {
      return '5회 이상 이동 후 패턴을 분석해요.';
    }
    return '정시율 ${profile.onTimeRate.toStringAsFixed(0)}% · '
        '추천 버퍼 +${profile.recommendedBuffer}분';
  }

  String _bufferDescription(int min) {
    switch (min) {
      case 5:
        return '가까운 거리, 주차 불필요할 때';
      case 10:
        return '일반적인 이동에 적당 (기본값)';
      case 15:
        return '주차나 건물 진입이 필요할 때';
      case 20:
        return '대형 건물, 복잡한 주차장';
      case 30:
        return '공항, 대규모 시설 방문 시';
      default:
        return '';
    }
  }

  Widget _divider() =>
      Divider(height: 1, indent: 62, color: Colors.grey.shade200);
}

// ── 아이콘 위젯 ──────────────────────────────────────
class _SettingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SettingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

// ── 지각 패턴 카드 ───────────────────────────────────
class _PunctualityCard extends StatelessWidget {
  final PunctualityProfile profile;
  const _PunctualityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text('이동 통계',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    )),
                const Spacer(),
                Text(profile.grade,
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),

            // 비율 바
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  _ratioBar(
                      profile.onTimeRate / 100, const Color(0xFF2D8A6E)),
                  _ratioBar(profile.lateRate / 100, Colors.orange),
                  _ratioBar(
                    (100 - profile.onTimeRate - profile.lateRate) / 100,
                    Colors.blue.shade300,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 범례
            Row(
              children: [
                _legend('정시', const Color(0xFF2D8A6E),
                    '${profile.onTimeRate.toStringAsFixed(0)}%'),
                const SizedBox(width: 12),
                _legend('지각', Colors.orange,
                    '${profile.lateRate.toStringAsFixed(0)}%'),
                const Spacer(),
                Text('${profile.totalTrips}회 기준',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),

            if (profile.recommendedBuffer > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '패턴 분석 결과, ${profile.recommendedBuffer}분의 '
                        '추가 여유시간이 자동 적용되고 있어요.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratioBar(double ratio, Color color) {
    if (ratio <= 0) return const SizedBox();
    return Expanded(
      flex: (ratio * 100).round().clamp(1, 100),
      child: Container(height: 6, color: color),
    );
  }

  Widget _legend(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text('$label $value',
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
