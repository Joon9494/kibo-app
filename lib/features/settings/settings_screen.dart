// =====================================================
// 📁 lib/features/settings/settings_screen.dart
// 역할: 설정 허브 화면 — 각 카테고리를 버튼으로 배치
//       탭하면 개별 설정 화면으로 이동
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_provider.dart';
import 'theme_settings_screen.dart';
import 'briefing_settings_screen.dart';
import 'calendar_manage_screen.dart';
import 'alarm_traffic_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'app_info_screen.dart';
import '../../core/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final assistantName = ref.watch(assistantNameProvider);
    final palette = ref.watch(themeProvider);
    final consent = ref.watch(privacyConsentProvider);
    final allConsented = consent.values.every((v) => v);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── 테마 & 비서 ──────────────────────────────
          _SettingsCategory(
            icon: Icons.palette_outlined,
            iconColor: palette.primary,
            iconBgColor: palette.primary.withOpacity(0.1),
            title: '테마 & 비서',
            subtitle: '${palette.label} · $assistantName',
            onTap: () => _push(context, const ThemeSettingsScreen()),
          ),

          const SizedBox(height: 10),

          // ── 브리핑 설정 ─────────────────────────────
          _SettingsCategory(
            icon: Icons.auto_awesome_outlined,
            iconColor: Colors.amber.shade700,
            iconBgColor: Colors.amber.withOpacity(0.1),
            title: '브리핑 설정',
            subtitle: '커스텀 프롬프트 · AI 브리핑 스타일',
            onTap: () => _push(context, const BriefingSettingsScreen()),
          ),

          const SizedBox(height: 10),

          // ── 캘린더 관리 ─────────────────────────────
          _SettingsCategory(
            icon: Icons.calendar_month_outlined,
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.withOpacity(0.1),
            title: '캘린더 관리',
            subtitle: '태그별 캘린더 추가 · 삭제 · Google 연동',
            onTap: () => _push(context, const CalendarManageScreen()),
          ),

          const SizedBox(height: 10),

          // ── 알람 및 교통 ────────────────────────────
          _SettingsCategory(
            icon: Icons.directions_car_outlined,
            iconColor: Colors.orange,
            iconBgColor: Colors.orange.withOpacity(0.1),
            title: '알람 및 교통',
            subtitle: '교통 예측 · 이동 추적 · 여유시간',
            onTap: () =>
                _push(context, const AlarmTrafficSettingsScreen()),
          ),

          const SizedBox(height: 10),

          // ── 개인정보 및 권한 ────────────────────────
          _SettingsCategory(
            icon: Icons.shield_outlined,
            iconColor: allConsented ? Colors.green : Colors.red,
            iconBgColor: (allConsented ? Colors.green : Colors.red)
                .withOpacity(0.1),
            title: '개인정보 및 권한',
            subtitle: allConsented ? '모든 권한 동의 완료' : '일부 권한 동의가 필요해요',
            onTap: () => _push(context, const PrivacySettingsScreen()),
          ),

          const SizedBox(height: 10),

          // ── 앱 정보 ─────────────────────────────────
          _SettingsCategory(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            iconBgColor: Colors.grey.withOpacity(0.08),
            title: '앱 정보',
            subtitle: 'KIBO 버전 · 라이선스',
            onTap: () => _push(context, const AppInfoScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

// ── 카테고리 버튼 위젯 ────────────────────────────────
class _SettingsCategory extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCategory({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),

              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // 화살표
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}