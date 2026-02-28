// =====================================================
// 📁 lib/features/settings/app_info_screen.dart
// 역할: 앱 정보 — 버전, 라이선스, 오픈소스
// =====================================================

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  String _version = '불러오는 중...';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '버전 정보 없음');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 앱 로고 & 이름 ─────────────────────────
          Center(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      '키',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KIBO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 일정 관리 비서',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v$_version${_buildNumber.isNotEmpty ? '+$_buildNumber' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── 정보 항목들 ────────────────────────────
          Card(
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.code,
                  title: '버전',
                  value: 'v$_version',
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.build_outlined,
                  title: '빌드 번호',
                  value: _buildNumber.isNotEmpty ? _buildNumber : '-',
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.flutter_dash,
                  title: '프레임워크',
                  value: 'Flutter',
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.cloud_outlined,
                  title: '백엔드',
                  value: 'Firebase + Gemini',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 링크들 ─────────────────────────────────
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('오픈소스 라이선스',
                      style: TextStyle(fontSize: 14)),
                  trailing: Icon(Icons.chevron_right,
                      color: Colors.grey.shade400),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'KIBO',
                      applicationVersion: 'v$_version',
                    );
                  },
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('개인정보처리방침',
                      style: TextStyle(fontSize: 14)),
                  trailing: Icon(Icons.chevron_right,
                      color: Colors.grey.shade400),
                  onTap: () {
                    // TODO: 개인정보처리방침 URL
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('개인정보처리방침 페이지는 준비 중이에요.')),
                    );
                  },
                ),
                _divider(),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('이용약관',
                      style: TextStyle(fontSize: 14)),
                  trailing: Icon(Icons.chevron_right,
                      color: Colors.grey.shade400),
                  onTap: () {
                    // TODO: 이용약관 URL
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('이용약관 페이지는 준비 중이에요.')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 크레딧 ─────────────────────────────────
          Center(
            child: Text(
              'Made with 🤖 + ❤️',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, indent: 56, color: Colors.grey.shade200);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.grey.shade500),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
