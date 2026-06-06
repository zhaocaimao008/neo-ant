import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PrivacySettingsPage extends StatefulWidget {
  final String userId;
  const PrivacySettingsPage({super.key, required this.userId});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _loading = true;
  bool _onlineStatus = true;
  bool _readReceipt = true;
  String _chatBackground = 'default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final result = await ApiService().getSettings(widget.userId);
      if (mounted) {
        setState(() {
          _onlineStatus = (result['privacy_online'] ?? 1) == 1;
          _readReceipt = (result['privacy_read_receipt'] ?? 1) == 1;
          _chatBackground = result['chat_background'] ?? 'default';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await ApiService().updateSettings(widget.userId, {key: value});
    } catch (_) {}
  }

  void _showBackgroundPicker() {
    final colors = [
      {'label': '默认', 'value': 'default'},
      {'label': '浅蓝', 'value': 'light_blue'},
      {'label': '浅绿', 'value': 'light_green'},
      {'label': '浅粉', 'value': 'light_pink'},
      {'label': '浅紫', 'value': 'light_purple'},
      {'label': '浅黄', 'value': 'light_yellow'},
      {'label': '深色', 'value': 'dark'},
      {'label': '星空', 'value': 'starry'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark
              ? const Color(0xFF141D4D)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择聊天背景',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF202124),
              )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                final selected = _chatBackground == c['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _chatBackground = c['value'] as String);
                    _updateSetting('chat_background', c['value']);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _bgColor(c['value'] as String),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: const Color(0xFF1AA4EC), width: 3)
                          : Border.all(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? const Color(0xFF2E2E2E)
                                  : const Color(0xFFE9E9E9)),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Color(0xFF1AA4EC))
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _bgColor(String value) {
    switch (value) {
      case 'light_blue': return const Color(0xFFE3F2FD);
      case 'light_green': return const Color(0xFFE8F5E9);
      case 'light_pink': return const Color(0xFFFCE4EC);
      case 'light_purple': return const Color(0xFFF3E5F5);
      case 'light_yellow': return const Color(0xFFFFFDE7);
      case 'dark': return const Color(0xFF263238);
      case 'starry': return const Color(0xFF1A237E);
      default: return Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF080C25)
          : const Color(0xFFF2F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C25) : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xE0101631) : const Color(0xE0FFFFFF),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFF5E5E5E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('隐私设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF202124),
          )),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingCard(isDark: isDark, children: [
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.visibility_outlined,
                    label: '在线状态',
                    subtitle: '让其他用户看到你的在线状态',
                    trailing: Switch(
                      value: _onlineStatus,
                      onChanged: (v) {
                        setState(() => _onlineStatus = v);
                        _updateSetting('privacy_online', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                  _Divider(isDark: isDark),
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.done_all_outlined,
                    label: '已读回执',
                    subtitle: '让对方知道你已经阅读了消息',
                    trailing: Switch(
                      value: _readReceipt,
                      onChanged: (v) {
                        setState(() => _readReceipt = v);
                        _updateSetting('privacy_read_receipt', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _SettingCard(isDark: isDark, children: [
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.wallpaper_outlined,
                    label: '聊天背景',
                    subtitle: '更改所有聊天的默认背景',
                    onTap: _showBackgroundPicker,
                  ),
                ]),
              ],
            ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D4D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20,
                  color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF202124))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFB2BAC2)
                                : const Color(0xFFAAAAAA))),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right, size: 18,
                      color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 48,
        color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9));
  }
}
