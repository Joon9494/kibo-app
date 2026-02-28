// =====================================================
// 📁 lib/features/settings/theme_settings_screen.dart
// 역할: 테마 팔레트 선택 + 비서 이름 설정
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() =>
      _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(assistantNameProvider),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPalette = ref.watch(themeProvider);
    final assistantName = ref.watch(assistantNameProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 외부 변경 반영
    ref.listen<String>(assistantNameProvider, (prev, next) {
      if (_nameController.text != next) {
        _nameController.text = next;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('테마 & 비서')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 비서 이름 ──────────────────────────────
          Text('내 비서 이름',
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
                  // 미리보기
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🤖',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"$assistantName, 내일 일정 알려줘"',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '이렇게 불러주시면 돼요!',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    '비서 이름을 자유롭게 설정하세요.\n'
                    '알림, 브리핑, 대화에 모두 반영돼요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _nameController,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: '예: 키보야, 아리아, 비서님',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.restore, size: 20),
                        tooltip: '기본값으로 되돌리기',
                        onPressed: () {
                          _nameController.text =
                              AssistantNameNotifier.defaultName;
                          ref
                              .read(assistantNameProvider.notifier)
                              .setName(AssistantNameNotifier.defaultName);
                          _showSnack('기본 이름으로 되돌렸어요.');
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(assistantNameProvider.notifier)
                            .setName(_nameController.text);
                        FocusScope.of(context).unfocus();
                        _showSnack(
                            '✅ "${_nameController.text.trim()}"(으)로 저장했어요!');
                      },
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── 테마 팔레트 ────────────────────────────
          Text('테마 팔레트',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),

          ...KiboPalette.values.map((palette) {
            final isSelected = palette == currentPalette;
            return _ThemeTile(
              palette: palette,
              isSelected: isSelected,
              onTap: () =>
                  ref.read(themeProvider.notifier).setPalette(palette),
            );
          }),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ── 테마 타일 (기존과 동일) ──────────────────────────
class _ThemeTile extends StatelessWidget {
  final KiboPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = palette.primary;
    final secondary = palette.secondary;
    final surface = palette.surfaceColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _ColorDot(color: primary),
                  const SizedBox(width: 4),
                  _ColorDot(color: secondary),
                  const SizedBox(width: 4),
                  _ColorDot(color: surface, bordered: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      palette.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: primary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: primary, size: 20)
                  else
                    Icon(Icons.circle_outlined,
                        color: Colors.grey.shade300, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool bordered;
  const _ColorDot({required this.color, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: Colors.grey.shade300) : null,
      ),
    );
  }
}
