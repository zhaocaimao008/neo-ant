import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ant_avatar.dart';
import 'call_page.dart';
import 'chat_page.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final bool isGroup;
  final int? memberCount;
  final String? userId;
  final String? conversationId;
  final String? groupId;
  const ProfilePage({
    super.key,
    required this.name,
    this.isGroup = false,
    this.memberCount,
    this.userId,
    this.conversationId,
    this.groupId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _muteNotifications = false;
  bool _loading = true;
  List<Map> _members = [];
  String? _error;

  // Real user data
  String _userName = '';
  String _userUsername = '';
  String _userPhone = '';
  String _userUniqueId = '';

  @override
  void initState() {
    super.initState();
    _userName = widget.name;
    if (widget.isGroup) {
      _loadMembers();
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      _loadUserData();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final result = await ApiService().getUser(widget.userId!);
      if (mounted) {
        setState(() {
          _userName = result['name'] ?? widget.name;
          _userUsername = result['username'] ?? '';
          _userPhone = result['phone'] ?? '';
          _userUniqueId = result['unique_id'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _userName = widget.name;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final phoneCtrl = TextEditingController(text: _userPhone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              if (newName.isNotEmpty && widget.userId != null) {
                try {
                  await ApiService().updateProfile(widget.userId!, name: newName, phone: newPhone);
                  if (mounted) {
                    setState(() {
                      _userName = newName;
                      _userPhone = newPhone;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('保存成功')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('保存失败: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMembers() async {
    final gid = widget.groupId ?? widget.conversationId ?? widget.name;
    try {
      final raw = await ApiService().getGroupMembers(gid);
      if (mounted) {
        setState(() {
          _members = raw.map((e) => e as Map).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showAddMemberDialog() {
    final usernameCtrl = TextEditingController();
    final gid = widget.groupId ?? widget.conversationId ?? widget.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加成员'),
        content: TextField(
          controller: usernameCtrl,
          decoration: const InputDecoration(
            labelText: '成员账号',
            hintText: '输入要邀请的成员账号',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim();
              if (username.isNotEmpty) {
                try {
                  final userId = widget.userId ?? '';
                  await ApiService().inviteGroupMember(gid, userId, username);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('邀请已发送')),
                    );
                    _loadMembers();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('邀请失败: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('发送邀请'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberConfirm(Map member) {
    final gid = widget.groupId ?? widget.conversationId ?? widget.name;
    final memberName = member['name'] ?? member['username'] ?? '未知';
    final memberId = member['id'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要将 $memberName 移出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ApiService().removeGroupMember(gid, memberId);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已移除 $memberName')),
                  );
                  _loadMembers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('移除失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('移除'),
          ),
        ],
      ),
    );
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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
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
                  color: isDark ? Colors.white : const Color(0xFF202124),
                )),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((c) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _bgColor(c['value'] as String, ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E2E2E)
                              : const Color(0xFFE9E9E9)),
                      ),
                      child: Center(
                        child: Text(c['label']!.substring(0, 2),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Color _bgColor(String value, BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    switch (value) {
      case 'light_blue': return const Color(0xFFE3F2FD);
      case 'light_green': return const Color(0xFFE8F5E9);
      case 'light_pink': return const Color(0xFFFCE4EC);
      case 'light_purple': return const Color(0xFFF3E5F5);
      case 'light_yellow': return const Color(0xFFFFFDE7);
      case 'dark': return const Color(0xFF263238);
      case 'starry': return const Color(0xFF1A237E);
      default: return isDark ? const Color(0xFF080C25) : const Color(0xFFF2F5F9);
    }
  }

  void _navigateToMessageSearch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showSearch(
      context: context,
      delegate: _MessageSearchDelegate(
        isDark: isDark,
        conversationId: widget.conversationId ?? '',
        userId: widget.userId ?? '',
      ),
    );
  }

  void _handleDeleteOrExit() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionLabel = widget.isGroup ? '退出群聊' : '删除联系人';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel),
        content: Text(widget.isGroup
            ? '确定退出该群聊吗？'
            : '确定删除该联系人吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (widget.isGroup) {
                  final gid = widget.groupId ?? widget.conversationId ?? '';
                  await ApiService().removeGroupMember(gid, widget.userId ?? '');
                } else {
                  await ApiService().removeContact(widget.userId ?? '', widget.name);
                }
                if (mounted) {
                  Navigator.pop(context); // Go back
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$actionLabel 成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('操作失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
          icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFF5E5E5E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isGroup ? '群聊信息' : '个人资料',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF202124))),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // Avatar & name
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    AntAvatar(text: _userName, size: 80),
                    if (widget.userId != null)
                      Positioned(
                        right: 0, bottom: 0,
                        child: GestureDetector(
                          onTap: _showEditProfileDialog,
                          child: Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1AA4EC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(_userName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF202124))),
                if (_userUsername.isNotEmpty && widget.userId != null) ...[
                  const SizedBox(height: 4),
                  Text('@${_userUsername}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                ],
                if (_userPhone.isNotEmpty && widget.userId != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_outlined, size: 13, color: Color(0xFFAAAAAA)),
                      const SizedBox(width: 4),
                      Text(_userPhone,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                    ],
                  ),
                ],
                if (_userUniqueId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('ID: ${_userUniqueId}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                  const SizedBox(height: 8),
                  // QR Code
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE9E9E9)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        'https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${Uri.encodeComponent(_userUniqueId)}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.qr_code, size: 40, color: Colors.grey)),
                      ),
                    ),
                  ),
                ],
                if (widget.isGroup && widget.memberCount != null) ...[
                  const SizedBox(height: 4),
                  Text('${widget.memberCount}人',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionChip(icon: Icons.message_outlined, label: '发消息', onTap: () {
                        final uid = ApiService().currentUserId;
                        if (uid.isEmpty || widget.userId == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatPage(
                            userId: uid,
                            conversationId: widget.userId!,
                            conversationName: widget.name,
                            online: true,
                            targetUserId: widget.userId!,
                          )),
                        );
                      }),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.userId != null ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CallPage(
                            userId: ApiService().currentUserId,
                            targetUserId: widget.userId!,
                            targetName: widget.name,
                            isVideo: false,
                          )),
                        );
                      } : null,
                      child: _ActionChip(icon: Icons.phone_outlined, label: '语音通话'),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.userId != null ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CallPage(
                            userId: ApiService().currentUserId,
                            targetUserId: widget.userId!,
                            targetName: widget.name,
                            isVideo: true,
                          )),
                        );
                      } : null,
                      child: _ActionChip(icon: Icons.videocam_outlined, label: '视频通话'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Group members section
          if (widget.isGroup) ...[
            _SectionHeader(isDark: isDark, label: '群成员 (${_members.length})',
              trailing: InkWell(
                onTap: _showAddMemberDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1AA4EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add, size: 14, color: Colors.white),
                      SizedBox(width: 3),
                      Text('添加成员', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _members.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(_error ?? '暂无成员',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
                          )),
                      )
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141D4D) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                        ),
                        child: Column(
                          children: _members.map((m) {
                            final memberName = m['name'] ?? m['username'] ?? '未知';
                            final memberId = m['id'] ?? '';
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onLongPress: () => _showRemoveMemberConfirm(m),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      AntAvatar(text: memberName.toString()[0], size: 36),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(memberName.toString(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF202124),
                                          )),
                                      ),
                                      Icon(Icons.swipe, size: 14,
                                        color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
            const SizedBox(height: 12),
          ],

          // Info section
          _InfoSection(isDark: isDark, items: [
            _InfoItem(
              icon: Icons.notifications_outlined,
              label: '消息免打扰',
              isDark: isDark,
              trailing: Switch(
                value: _muteNotifications,
                onChanged: (v) => setState(() => _muteNotifications = v),
                activeColor: const Color(0xFF1AA4EC),
              ),
            ),
            _InfoItem(
              icon: Icons.search,
              label: '查找聊天记录',
              isDark: isDark,
              onTap: _navigateToMessageSearch,
            ),
            _InfoItem(
              icon: Icons.wallpaper_outlined,
              label: '当前聊天背景',
              isDark: isDark,
              onTap: _showBackgroundPicker,
            ),
          ]),
          const SizedBox(height: 12),

          _InfoSection(isDark: isDark, items: [
            _InfoItem(
              icon: Icons.report_outlined,
              label: '投诉',
              isDark: isDark,
              iconColor: const Color(0xFFFF3B30),
              txtColor: const Color(0xFFFF3B30),
            ),
            _InfoItem(
              icon: Icons.delete_outline,
              label: widget.isGroup ? '退出群聊' : '删除联系人',
              isDark: isDark,
              iconColor: const Color(0xFFFF3B30),
              txtColor: const Color(0xFFFF3B30),
              onTap: _handleDeleteOrExit,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final bool isDark;
  final String label;
  final Widget? trailing;
  const _SectionHeader({required this.isDark, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
            )),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MessageSearchDelegate extends SearchDelegate<String?> {
  final bool isDark;
  final String conversationId;
  final String userId;

  _MessageSearchDelegate({
    required this.isDark,
    required this.conversationId,
    required this.userId,
  });

  @override
  String get searchFieldLabel => '搜索聊天记录';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xE0101631) : const Color(0xE0FFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFF5E5E5E)),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody(context);

  Widget _buildSearchBody(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
            const SizedBox(height: 8),
            Text('输入关键词搜索聊天记录',
              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
          ],
        ),
      );
    }

    return FutureBuilder<List>(
      future: ApiService().searchMessages(userId, query),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                const SizedBox(height: 8),
                Text('未找到相关消息',
                  style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
              ],
            ),
          );
        }

        final results = snap.data!;
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => Divider(height: 1,
            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
          itemBuilder: (_, i) {
            final msg = results[i] as Map;
            return ListTile(
              leading: AntAvatar(
                text: (msg['senderName'] ?? '?').toString()[0],
                size: 40,
              ),
              title: Text(
                msg['text'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
              subtitle: Text(
                msg['senderName'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
                ),
              ),
              dense: true,
              onTap: () => close(context, msg['text'] as String?),
            );
          },
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF1AA4EC)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final bool isDark;
  final List<Widget> items;
  const _InfoSection({required this.isDark, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D4D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
      ),
      child: Column(children: items),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Widget? trailing;
  final Color? iconColor;
  final Color? txtColor;
  final VoidCallback? onTap;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.isDark,
    this.trailing,
    this.iconColor,
    this.txtColor,
    this.onTap,
  });

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
              Icon(icon, size: 20, color: iconColor ?? (isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
              const SizedBox(width: 14),
              Expanded(child: Text(label,
                style: TextStyle(fontSize: 14, color: txtColor ?? (isDark ? Colors.white : const Color(0xFF202124))))),
              trailing ?? Icon(Icons.chevron_right, size: 18, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}
