// =====================================================
// 📁 lib/features/settings/privacy_settings_screen.dart
// 역할: 개인정보 및 권한 동의 관리
//       위치, 캘린더, 알림, 데이터 수집, AI 분석 동의
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_provider.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(privacyConsentProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final allAccepted = consent.values.every((v) => v);

    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 및 권한')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 전체 상태 ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: allAccepted
                  ? Colors.green.withOpacity(0.06)
                  : Colors.orange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: allAccepted
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  allAccepted
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: allAccepted ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allAccepted
                            ? '모든 권한에 동의하셨어요'
                            : '일부 권한 동의가 필요해요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: allAccepted
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allAccepted
                            ? '키보의 모든 기능을 이용할 수 있어요.'
                            : '동의하지 않은 항목의 기능이 제한될 수 있어요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 필수 동의 ──────────────────────────────
          Text('필수 동의',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          _ConsentCard(
            icon: Icons.location_on_outlined,
            iconColor: Colors.blue,
            title: '위치 정보 접근',
            description:
                '교통 예측 알람, 이동 시간 계산, 도착 감지에 필요해요.\n'
                '위치 정보는 이동 추적 중에만 사용되며, '
                '서버에 영구 저장하지 않아요.',
            required: true,
            isAccepted: consent['location'] ?? false,
            onChanged: (v) => ref
                .read(privacyConsentProvider.notifier)
                .setConsent('location', v),
          ),

          _ConsentCard(
            icon: Icons.calendar_month_outlined,
            iconColor: Colors.green,
            title: 'Google 캘린더 접근',
            description:
                '일정 읽기/쓰기, 태그별 캘린더 관리에 필요해요.\n'
                'Google 계정으로 인증하며, 키보 외의 캘린더는 '
                '접근하지 않아요.',
            required: true,
            isAccepted: consent['calendar'] ?? false,
            onChanged: (v) => ref
                .read(privacyConsentProvider.notifier)
                .setConsent('calendar', v),
          ),

          _ConsentCard(
            icon: Icons.notifications_outlined,
            iconColor: Colors.orange,
            title: '알림 권한',
            description:
                '출발 알림, 교통 악화 알림, 브리핑 알림에 필요해요.\n'
                '알림은 설정에서 개별 끌 수 있어요.',
            required: true,
            isAccepted: consent['notification'] ?? false,
            onChanged: (v) => ref
                .read(privacyConsentProvider.notifier)
                .setConsent('notification', v),
          ),

          const SizedBox(height: 20),

          // ── 선택 동의 ──────────────────────────────
          Text('선택 동의',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          _ConsentCard(
            icon: Icons.analytics_outlined,
            iconColor: Colors.purple,
            title: '사용 데이터 수집',
            description:
                '앱 사용 패턴(화면 이동, 기능 사용 빈도)을 수집해\n'
                '서비스 개선에 활용해요. 개인 일정 내용은 수집하지 않아요.',
            required: false,
            isAccepted: consent['data_collection'] ?? false,
            onChanged: (v) => ref
                .read(privacyConsentProvider.notifier)
                .setConsent('data_collection', v),
          ),

          _ConsentCard(
            icon: Icons.psychology_outlined,
            iconColor: Colors.teal,
            title: 'AI 분석 동의',
            description:
                '브리핑 생성, 지각 패턴 학습에 AI 분석이 사용돼요.\n'
                '일정 데이터는 Gemini API로 전송되며, '
                'Google의 데이터 보호 정책을 따라요.\n'
                'AI 학습에 개인 데이터가 사용되지 않아요.',
            required: false,
            isAccepted: consent['ai_processing'] ?? false,
            onChanged: (v) => ref
                .read(privacyConsentProvider.notifier)
                .setConsent('ai_processing', v),
          ),

          const SizedBox(height: 20),

          // ── 전체 동의 버튼 ─────────────────────────
          if (!allAccepted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(privacyConsentProvider.notifier)
                      .acceptAll();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ 모든 권한에 동의했어요!')),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('모든 항목에 동의하기'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── 개인정보처리방침 링크 ──────────────────
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: 개인정보처리방침 URL 연결
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('개인정보처리방침 페이지는 준비 중이에요.'),
                  ),
                );
              },
              child: Text(
                '개인정보처리방침 전문 보기',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 동의 카드 ────────────────────────────────────────
class _ConsentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool required;
  final bool isAccepted;
  final ValueChanged<bool> onChanged;

  const _ConsentCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.required,
    required this.isAccepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isAccepted
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: required
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                required ? '필수' : '선택',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: required
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isAccepted,
                    onChanged: onChanged,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
