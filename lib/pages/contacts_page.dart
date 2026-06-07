import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mock_data.dart';
import '../widgets/ant_avatar.dart';
import '../widgets/bottom_sheets.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import '../services/api_service.dart';

class ContactsPage extends StatefulWidget {
  final String userId;
  const ContactsPage({super.key, required this.userId});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _loading = true;
  bool _loadingRequests = false;
  StreamSubscription<Map>? _contactSub;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadFriendRequests();
    _searchCtrl.addListener(_filterContacts);
    // Listen for contact:added events via WebSocket
    _contactSub = ApiService().contactStream.listen((_) {
      _loadContacts();
      _loadFriendRequests();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filterContacts);
    _searchCtrl.dispose();
    _contactSub?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final raw = await ApiService().getContacts(widget.userId);
      final list = raw.cast<Map<String, dynamic>>();
      _contacts = list;
      _filterContacts();
    } catch (_) {
      _contacts = [];
      _filteredContacts = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFriendRequests() async {
    if (_loadingRequests) return;
    setState(() => _loadingRequests = true);
    try {
      final data = await ApiService().getFriendRequests(widget.userId);
      if (mounted) {
        setState(() {
          _friendRequests = data.cast<Map<String, dynamic>>();
          _loadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  void _showFriendRequestsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E254A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('好友请求',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
              ),
              const Divider(height: 1),
              Expanded(
                child: _friendRequests.isEmpty
                  ? Center(
                      child: Text('暂无好友请求',
                        style: TextStyle(fontSize: 14,
                          color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _friendRequests.length,
                      itemBuilder: (ctx, i) {
                        final req = _friendRequests[i];
                        final fromName = req['from_name']?.toString() ?? '未知用户';
                        final reqId = req['id']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              // Avatar
                              AntAvatar(text: fromName, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(fromName,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : const Color(0xFF202124))),
                              ),
                              const SizedBox(width: 8),
                              // Accept button
                              Container(
                                width: 64, height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1AA4EC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _acceptFriendRequest(reqId, fromName, ctx),
                                    child: const Center(
                                      child: Text('接受', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reject button
                              Container(
                                width: 64, height: 32,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252B44) : const Color(0xFFF2F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _rejectFriendRequest(reqId, ctx),
                                    child: Center(
                                      child: Text('拒绝', style: TextStyle(fontSize: 13,
                                        color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(String requestId, String fromName, BuildContext sheetCtx) async {
    try {
      await ApiService().respondToFriendRequest(requestId, 'accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 $fromName 为好友'), duration: const Duration(seconds: 2)),
        );
      }
      // Reload
      _loadFriendRequests();
      _loadContacts();
      Navigator.of(sheetCtx).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId, BuildContext sheetCtx) async {
    try {
      await ApiService().respondToFriendRequest(requestId, 'rejected');
      _loadFriendRequests();
      Navigator.of(sheetCtx).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  void _filterContacts() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredContacts = List.from(_contacts);
      } else {
        _filteredContacts = _contacts
            .where((c) => (c['name'] as String? ?? '').toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _showAddFriendDialog() async {
    // Step 1: choose method
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: Text('添加好友',
            style: TextStyle(color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outlined, color: Color(0xFF1AA4EC)),
                title: const Text('搜索账号'),
                onTap: () => Navigator.of(ctx).pop('username'),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: Color(0xFF1AA4EC)),
                title: const Text('搜索手机号'),
                onTap: () => Navigator.of(ctx).pop('phone'),
              ),
            ],
          ),
        );
      },
    );
    if (method == null) return;

    // Step 2: input value
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: Text(method == 'username' ? '搜索账号' : '搜索手机号',
            style: TextStyle(color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: method == 'username' ? '输入对方账号' : '输入对方手机号',
              hintStyle: TextStyle(fontSize: 13,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
              border: InputBorder.none,
              filled: true,
              fillColor: isDark ? const Color(0xFF111630) : const Color(0xFFF2F5F9),
            ),
            style: TextStyle(fontSize: 14,
              color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124)),
            keyboardType: method == 'phone' ? TextInputType.phone : TextInputType.text,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消',
                style: TextStyle(color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
            ),
            TextButton(
              onPressed: () {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) Navigator.of(ctx).pop(val);
              },
              child: Text('发送', style: const TextStyle(color: Color(0xFF1AA4EC))),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      try {
        await ApiService().addContact(widget.userId, method == 'username' ? result : '',
            contactPhone: method == 'phone' ? result : null);
        _loadContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('好友请求已发送')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = MockData.groups;
    final contacts = _filteredContacts;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in contacts) {
      final group = c['group'] as String? ?? '联系人';
      grouped.putIfAbsent(group, () => []).add(c);
    }

    return Column(
      children: [
        _Header(
          isDark: isDark,
          onAddFriend: _showAddFriendDialog,
        ),
        _SearchBar(ctrl: _searchCtrl, isDark: isDark),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadContacts,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      // Friend request row
                      _FriendRequestTile(
                        pendingCount: _friendRequests.length,
                        isDark: isDark,
                        onTap: _showFriendRequestsSheet,
                      ),
                      const SizedBox(height: 4),
                      _SectionLabel(label: '群组', isDark: isDark),
                      ...groups.map((g) => _GroupTile(g: g, isDark: isDark)),
                      Divider(indent: 16, endIndent: 16, height: 1,
                        color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
                      if (contacts.isEmpty && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('暂无联系人',
                              style: TextStyle(fontSize: 13,
                                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                          ),
                        )
                      else
                        ...grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(label: entry.key, isDark: isDark),
                              ...entry.value.map((c) => _ContactTile(c: c, isDark: isDark, userId: widget.userId)),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  final int pendingCount;
  final bool isDark;
  final VoidCallback onTap;
  const _FriendRequestTile({required this.pendingCount, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_add_outlined, size: 22, color: Colors.white),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            pendingCount > 99 ? '99+' : pendingCount.toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('新的好友',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF202124))),
              ),
              Icon(Icons.chevron_right, size: 18,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAddFriend;
  const _Header({required this.isDark, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text('联系人', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
          const Spacer(),
          _IconBtn(Icons.person_add_alt_1, isDark, onTap: onAddFriend),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  const _SearchBar({required this.ctrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D4D) : const Color(0xFFF2F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: '搜索联系人',
            hintStyle: TextStyle(fontSize: 13,
              color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            prefixIcon: Icon(Icons.search, size: 18,
              color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          style: TextStyle(fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF202124)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupItem g;
  final bool isDark;
  const _GroupTile({required this.g, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatPage(
              userId: '',
              conversationId: g.name.hashCode.toString(),
              conversationName: g.name,
              isGroup: true,
              online: g.online,
            )),
          );
        },
        onLongPress: () {
          showShareSheet(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              AntAvatar(text: g.name, size: 40, showOnline: g.online),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(g.name, style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF202124))),
                    const SizedBox(width: 4),
                    Text('(${g.members}人)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18,
                color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> c;
  final bool isDark;
  final String userId;
  const _ContactTile({required this.c, required this.isDark, required this.userId});

  @override
  Widget build(BuildContext context) {
    final name = c['name'] as String? ?? '';
    final status = c['status'] as String? ?? '';
    final online = (c['status'] as String?) != '离线';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatPage(
              userId: userId,
              conversationId: c['id'] as String? ?? name,
              conversationName: name,
              online: online,
              targetUserId: c['id'] as String? ?? '',
            )),
          );
        },
        onLongPress: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfilePage(
              name: name,
              userId: c['id'] as String? ?? '',
            )),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              AntAvatar(text: name, size: 40, showOnline: online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF202124))),
                    const SizedBox(height: 2),
                    Text(status,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;
  const _IconBtn(this.icon, this.isDark, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34, height: 34, alignment: Alignment.center,
          child: Icon(icon, size: 20,
            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF5E5E5E)),
        ),
      ),
    );
  }
}
