// =====================================================
// 📁 lib/features/settings/settings_screen.dart
// 역할: 앱 설정 화면 — 테마 선택 등
// =====================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPalette = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '테마',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
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
          const SizedBox(height: 32),
          Text(
            '앱 정보',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('버전'),
              trailing: Text(
                'v1.0.0',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final primary  = palette.primary;
    final secondary = palette.secondary;
    final surface  = palette.surfaceColor; // ✅ theme.dart의 surfaceColor와 일치

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
        // ✅ GestureDetector → Material + InkWell (Ripple Effect)
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
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
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
        border: bordered
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
    );
  }
}