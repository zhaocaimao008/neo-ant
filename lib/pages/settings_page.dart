import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../widgets/ant_avatar.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'privacy_settings_page.dart';
import 'notification_settings_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_2fa_page.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  const SettingsPage({super.key, required this.userId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _userName = '';
  String _userUsername = '';
  String _userRole = ''; // 'admin' or 'user'

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final result = await ApiService().getUser(widget.userId);
      if (mounted) {
        setState(() {
          _userName = result['name'] ?? '';
          _userUsername = result['username'] ?? '';
          _userRole = result['role'] ?? 'user';
        });
      }
    } catch (_) {}
  }

  String get _displayName => _userName.isNotEmpty ? _userName : '用户';
  String get _displayUsername => _userUsername.isNotEmpty ? _userUsername : '';

  void _showAccountSecurityDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改昵称'),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: '新昵称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await ApiService().updateProfile(widget.userId, name: newName);
                  if (mounted) {
                    setState(() => _userName = newName);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新成功')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新失败: $e')),
                    );
                  }
                }
              }
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog() {
    final countCtrl = TextEditingController(text: '5');
    setState(() {});

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151B3A) : Colors.white,
          title: const Row(
            children: [
              Icon(Icons.vpn_key, size: 20, color: Color(0xFF1AA4EC)),
              SizedBox(width: 8),
              Text('邀请码管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: countCtrl,
                        decoration: const InputDecoration(
                          labelText: '数量',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final count = int.tryParse(countCtrl.text) ?? 1;
                        try {
                          final result = await ApiService().generateInviteCodes(widget.userId, count: count);
                          if (mounted && result['ok'] == true) {
                            final codes = (result['codes'] as List).join(', ');
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已生成 ${count} 个邀请码')),
                            );
                            _showInviteCodeList();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('生成失败: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1AA4EC),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('生成'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showInviteCodeList(); },
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('查看已有邀请码'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('关闭', style: TextStyle(color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
            ),
          ],
        );
      },
    );
  }

  void _showInviteCodeList() async {
    try {
      final codes = await ApiService().listInviteCodes(widget.userId);
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151B3A) : Colors.white,
          title: const Text('已生成邀请码'),
          content: SizedBox(
            width: double.maxFinite,
            child: codes.isEmpty
              ? const Text('暂无邀请码')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: codes.take(50).map((c) {
                    final code = c['code'] ?? '';
                    final used = c['used_count'] ?? 0;
                    final maxUses = c['max_uses'] ?? 1;
                    final creator = c['creator_name'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(code, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                          const Spacer(),
                          Text('$used/$maxUses', style: TextStyle(fontSize: 12, color: used >= maxUses ? Colors.red : Colors.green)),
                          const SizedBox(width: 8),
                          Text(creator, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('关闭', style: TextStyle(color: const Color(0xFF1AA4EC))),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载失败')),
        );
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF151B3A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1AA4EC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bug_report, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Ant Messenger',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aboutRow('版本', 'v1.0.0', isDark),
              const SizedBox(height: 8),
              _aboutRow('平台', 'Flutter / Dart', isDark),
              const SizedBox(height: 8),
              Text(
                'Ant Messenger 是一款采用 Flutter 构建的现代化即时通讯应用。支持文字、图片、语音消息，群聊，音视频通话等功能。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _aboutRow(String label, String value, bool isDark) {
    return Row(
      children: [
        Text(label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
          )),
        const Spacer(),
        Text(value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124),
          )),
      ],
    );
  }

  void _showFavoritesDialog() async {
    try {
      final result = await ApiService().getFavorites(widget.userId);
      final dynamic raw = result['favorites'];
      final List favorites = raw is List ? raw : [];
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151B3A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, size: 20, color: Color(0xFFFAAD14)),
                  const SizedBox(width: 8),
                  Text('收藏消息',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124),
                    )),
                  const Spacer(),
                  Text('${favorites.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
                    )),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: favorites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_border, size: 48,
                              color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
                            const SizedBox(height: 8),
                            Text('暂无收藏消息',
                              style: TextStyle(fontSize: 14,
                                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) => Divider(height: 1,
                          color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
                        itemBuilder: (_, i) {
                          final f = favorites[i] as Map;
                          return ListTile(
                            leading: AntAvatar(
                              text: (f['senderName'] ?? '?').toString()[0],
                              size: 40,
                            ),
                            title: Text(
                              f['text'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124),
                              ),
                            ),
                            subtitle: Text(
                              f['senderName'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
                              ),
                            ),
                            dense: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载收藏失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          child: Row(
            children: [
              Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _showFavoritesDialog,
                  child: Container(
                    width: 34, height: 34, alignment: Alignment.center,
                    child: const Icon(Icons.star_border, size: 20, color: Color(0xFFFAAD14)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Profile
        _ProfileCard(isDark: isDark, name: _displayName, username: _displayUsername, userId: widget.userId),
        const SizedBox(height: 12),

        // Account
        _SectionCard(isDark: isDark, children: [
          _SettingItem(isDark: isDark, icon: Icons.lock_outlined, label: '账户安全', onTap: _showAccountSecurityDialog),
          _Divider(isDark: isDark),
          _SettingItem(isDark: isDark, icon: Icons.shield_outlined, label: '隐私', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PrivacySettingsPage(userId: widget.userId)),
            );
          }),
        ]),
        const SizedBox(height: 12),

        // General
        _SectionCard(isDark: isDark, children: [
          _SettingItem(isDark: isDark, icon: Icons.notifications_outlined, label: '通知', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NotificationSettingsPage(userId: widget.userId)),
            );
          }),
          _Divider(isDark: isDark),
          _SettingItem(isDark: isDark, icon: Icons.devices_outlined, label: '多设备', onTap: () {}),
          _Divider(isDark: isDark),
          _SettingItem(isDark: isDark, icon: Icons.palette_outlined, label: '深色模式', onTap: () {
            final app = NeoAntApp.of(context);
            if (app != null) app.toggleTheme();
          }, trailing: Switch(
            value: isDark,
            onChanged: (_) {
              final app = NeoAntApp.of(context);
              if (app != null) app.toggleTheme();
            },
            activeColor: const Color(0xFF1AA4EC),
          )),
        ]),
        const SizedBox(height: 12),

        // About
        _SectionCard(isDark: isDark, children: [
          if (_userRole == 'admin')
            _SettingItem(isDark: isDark, icon: Icons.vpn_key_outlined, label: '邀请码管理', onTap: _showInviteCodeDialog),
          if (_userRole == 'admin') _Divider(isDark: isDark),
          if (_userRole == 'admin')
            _SettingItem(isDark: isDark, icon: Icons.dashboard_outlined, label: '管理后台', onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AdminDashboardPage(userId: widget.userId)),
              );
            }),
          if (_userRole == 'admin') _Divider(isDark: isDark),
          if (_userRole == 'admin')
            _SettingItem(isDark: isDark, icon: Icons.security_outlined, label: '双重验证', onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Admin2faPage()),
              );
            }),
          if (_userRole == 'admin') _Divider(isDark: isDark),
          _SettingItem(isDark: isDark, icon: Icons.info_outline, label: '关于应用', onTap: _showAboutDialog,
            trailing: Text('v1.0.0', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)))),
        ]),
        const SizedBox(height: 24),

        // Logout
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              ApiService().disconnectWs();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('userId');
              const storage = FlutterSecureStorage();
              await storage.delete(key: 'authToken');
              ApiService().logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (r) => false,
              );
            },
            icon: const Icon(Icons.logout, size: 16, color: Color(0xFFFF3B30)),
            label: Text('退出登录', style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final bool isDark;
  final String name;
  final String username;
  final String userId;
  const _ProfileCard({required this.isDark, required this.name, required this.username, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF151B3A) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfilePage(name: name, userId: userId)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
          ),
          child: Row(
            children: [
              AntAvatar(text: name.isNotEmpty ? name[0] : '?', size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('@$username', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SectionCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B3A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingItem({required this.isDark, required this.icon, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124)))),
              trailing ?? Icon(Icons.chevron_right, size: 18, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
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
    return Divider(height: 0.5, thickness: 0.5, indent: 48,
      color: isDark ? const Color(0xFF1F2546) : const Color(0xFFE9E9E9));
  }
}
