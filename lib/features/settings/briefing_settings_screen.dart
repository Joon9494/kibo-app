// =====================================================
// 📁 lib/features/settings/briefing_settings_screen.dart
// 역할: 브리핑 커스텀 프롬프트 설정
//       기본 프롬프트와의 관계를 명확히 안내
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_provider.dart';

class BriefingSettingsScreen extends ConsumerStatefulWidget {
  const BriefingSettingsScreen({super.key});

  @override
  ConsumerState<BriefingSettingsScreen> createState() =>
      _BriefingSettingsScreenState();
}

class _BriefingSettingsScreenState
    extends ConsumerState<BriefingSettingsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(briefingPromptProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assistantName = ref.watch(assistantNameProvider);

    ref.listen<String>(briefingPromptProvider, (prev, next) {
      if (_controller.text != next) _controller.text = next;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('브리핑 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 작동 방식 안내 ─────────────────────────
          _InfoCard(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber.shade700,
            title: '브리핑은 이렇게 만들어져요',
            items: const [
              '① 기본 프롬프트가 날씨·일정·교통 정보를 수집해요.',
              '② 커스텀 프롬프트를 기본 프롬프트에 추가 반영해요.',
              '③ AI가 두 프롬프트를 조화롭게 합쳐서 브리핑을 생성해요.',
            ],
          ),

          const SizedBox(height: 16),

          // ── 커스텀 프롬프트 입력 ───────────────────
          Text('커스텀 프롬프트',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '브리핑에 항상 반영하고 싶은 내용을 적어주세요.\n'
                    '기본 브리핑 위에 추가로 적용됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: '예: 날씨 정보 꼭 포함해줘, 짧게 요점만',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.3),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savePrompt,
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── 예시 프롬프트 ──────────────────────────
          Text('이런 프롬프트를 써보세요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          _ExampleChip(
            label: '☀️ 날씨를 항상 먼저 알려줘',
            onTap: () => _controller.text = '날씨를 항상 먼저 알려줘',
          ),
          _ExampleChip(
            label: '📋 핵심만 3줄로 요약해줘',
            onTap: () => _controller.text = '핵심만 3줄로 요약해줘',
          ),
          _ExampleChip(
            label: '🚗 출퇴근 교통 정보 빠지지 않게 해줘',
            onTap: () => _controller.text = '출퇴근 교통 정보 빠지지 않게 해줘',
          ),
          _ExampleChip(
            label: '😊 친구처럼 편하게 말해줘',
            onTap: () => _controller.text = '친구처럼 편하게 말해줘',
          ),
          _ExampleChip(
            label: '📊 시간순으로 정리해줘',
            onTap: () => _controller.text = '시간순으로 정리해줘',
          ),

          const SizedBox(height: 20),

          // ── 미리보기 ──────────────────────────────
          Text('브리핑 미리보기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$assistantName의 아침 브리핑',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '좋은 아침이에요! 오늘 일정을 정리해드릴게요.\n\n'
                  '☀️ 서울 맑음, 최고 12°C\n'
                  '📅 오후 2시 미팅 — 강남역 (🚇 45분)\n'
                  '💡 12:45까지 출발하면 여유 있어요!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get assistantName {
    final name = ref.read(assistantNameProvider);
    // "~야" 형태면 "~" 만 사용, 아니면 그대로
    if (name.endsWith('야') || name.endsWith('아')) {
      return name.substring(0, name.length - 1);
    }
    return name;
  }

  void _savePrompt() {
    ref
        .read(briefingPromptProvider.notifier)
        .setPrompt(_controller.text.trim());
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 브리핑 설정이 저장됐어요!')),
    );
  }
}

// ── 안내 카드 ─────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ── 예시 프롬프트 칩 ──────────────────────────────────
class _ExampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExampleChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Icon(Icons.content_copy, size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
