import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  final String userId;
  const NotificationSettingsPage({super.key, required this.userId});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _notifyNewMsg = true;
  bool _notifySound = true;
  bool _notifyVibrate = true;
  bool _showPreview = true;

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
          _notifyNewMsg = (result['notify_new_msg'] ?? 1) == 1;
          _notifySound = (result['notify_sound'] ?? 1) == 1;
          _notifyVibrate = (result['notify_vibrate'] ?? 1) == 1;
          _showPreview = (result['notify_preview'] ?? 1) == 1;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080C25) : const Color(0xFFF2F5F9),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xE0101631) : const Color(0xE0FFFFFF),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFF5E5E5E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('新消息通知',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF202124))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle(
                    isDark: isDark, title: '消息通知'),
                const SizedBox(height: 4),
                _SettingCard(isDark: isDark, children: [
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.notifications_active_outlined,
                    label: '新消息通知',
                    subtitle: '接收新消息时推送通知',
                    trailing: Switch(
                      value: _notifyNewMsg,
                      onChanged: (v) {
                        setState(() => _notifyNewMsg = v);
                        _updateSetting('notify_new_msg', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                  _Divider(isDark: isDark),
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.volume_up_outlined,
                    label: '声音',
                    subtitle: '新消息时播放提示音',
                    trailing: Switch(
                      value: _notifySound,
                      onChanged: (v) {
                        setState(() => _notifySound = v);
                        _updateSetting('notify_sound', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                  _Divider(isDark: isDark),
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.vibration_outlined,
                    label: '振动',
                    subtitle: '新消息时振动提醒',
                    trailing: Switch(
                      value: _notifyVibrate,
                      onChanged: (v) {
                        setState(() => _notifyVibrate = v);
                        _updateSetting('notify_vibrate', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                  _Divider(isDark: isDark),
                  _SettingRow(
                    isDark: isDark,
                    icon: Icons.preview_outlined,
                    label: '消息预览',
                    subtitle: '在通知栏显示消息内容',
                    trailing: Switch(
                      value: _showPreview,
                      onChanged: (v) {
                        setState(() => _showPreview = v);
                        _updateSetting('notify_preview', v ? 1 : 0);
                      },
                      activeColor: const Color(0xFF1AA4EC),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final bool isDark;
  final String title;
  const _SectionTitle({required this.isDark, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
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
              Icon(icon,
                  size: 20,
                  color: isDark
                      ? const Color(0xFFB2BAC2)
                      : const Color(0xFFAAAAAA)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF202124))),
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
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: isDark
                          ? const Color(0xFFB2BAC2)
                          : const Color(0xFFAAAAAA)),
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
