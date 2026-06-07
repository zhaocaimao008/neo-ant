import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  final String userId;
  const AdminDashboardPage({super.key, required this.userId});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map _stats = {};
  List _users = [];
  List _inviteCodes = [];
  bool _loadingStats = true;
  bool _loadingUsers = true;
  bool _loadingCodes = true;
  int _userPage = 1;
  int _codePage = 1;
  final _codeCountCtrl = TextEditingController(text: '5');
  final _codeMaxUsesCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUsers();
    _loadInviteCodes();
  }

  @override
  void dispose() {
    _codeCountCtrl.dispose();
    _codeMaxUsesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final result = await ApiService().adminGetStats();
      if (mounted) setState(() { _stats = result; _loadingStats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final result = await ApiService().adminGetUsers(page: _userPage, limit: 50);
      if (mounted) {
        setState(() {
          final dynamic raw = result['users'];
          _users = raw is List ? raw : [];
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadInviteCodes() async {
    setState(() => _loadingCodes = true);
    try {
      final result = await ApiService().adminGetInviteCodes(page: _codePage, limit: 50);
      if (mounted) {
        setState(() {
          final dynamic raw = result['codes'];
          _inviteCodes = raw is List ? raw : [];
          _loadingCodes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCodes = false);
    }
  }

  Future<void> _banUser(String userId, bool ban) async {
    try {
      await ApiService().adminBanUser(userId, ban: ban);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ban ? '已封禁用户' : '已解封用户')),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF080C25) : const Color(0xFFF2F5F9),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xE0111735) : const Color(0xE0FFFFFF),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF5A6180) : const Color(0xFF5E5E5E)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('管理后台', style: TextStyle(fontWeight: FontWeight.w600)),
          bottom: const TabBar(
            tabs: [
              Tab(text: '概览'),
              Tab(text: '用户管理'),
              Tab(text: '邀请码'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStatsTab(isDark),
            _buildUsersTab(isDark),
            _buildInviteCodesTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(bool isDark) {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());

    final users = _stats['users'] ?? 0;
    final messages = _stats['messages'] ?? 0;
    final conversations = _stats['conversations'] ?? 0;
    final inviteCodes = _stats['inviteCodes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _StatCard(label: '注册用户', value: '$users', icon: Icons.people, color: const Color(0xFF1AA4EC), isDark: isDark),
          const SizedBox(height: 12),
          _StatCard(label: '消息总数', value: '$messages', icon: Icons.message, color: const Color(0xFF52C41A), isDark: isDark),
          const SizedBox(height: 12),
          _StatCard(label: '对话数', value: '$conversations', icon: Icons.chat, color: const Color(0xFFFAAD14), isDark: isDark),
          const SizedBox(height: 12),
          _StatCard(label: '邀请码', value: '$inviteCodes', icon: Icons.vpn_key, color: const Color(0xFF722ED1), isDark: isDark),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新数据'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isDark) {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final user = _users[i] as Map;
          final uid = (user['id'] ?? user['_id'] ?? '').toString();
          final name = user['name'] ?? user['username'] ?? '未知';
          final banned = user['banned'] == true;
          final role = user['role'] ?? 'user';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151B3A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: banned ? Colors.grey : const Color(0xFF1AA4EC),
                child: Text(name.toString()[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text('$name', style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF202124),
                decoration: banned ? TextDecoration.lineThrough : null,
              )),
              subtitle: Text('ID: $uid 角色: $role',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
              trailing: ElevatedButton(
                onPressed: () => _banUser(uid, !banned),
                style: ElevatedButton.styleFrom(
                  backgroundColor: banned ? const Color(0xFF52C41A) : const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: Size.zero,
                ),
                child: Text(banned ? '解封' : '封禁', style: const TextStyle(fontSize: 12)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInviteCodesTab(bool isDark) {
    return Column(
      children: [
        // Generate section
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151B3A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('生成邀请码', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _codeCountCtrl,
                      decoration: const InputDecoration(labelText: '数量', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _codeMaxUsesCtrl,
                      decoration: const InputDecoration(labelText: '最大使用次数', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final count = int.tryParse(_codeCountCtrl.text) ?? 1;
                      final maxUses = int.tryParse(_codeMaxUsesCtrl.text) ?? 1;
                      try {
                        await ApiService().adminGenerateInviteCodes(count: count, maxUses: maxUses);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已生成 $count 个邀请码')),
                          );
                          _loadInviteCodes();
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
            ],
          ),
        ),
        // Code list
        Expanded(
          child: _loadingCodes
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadInviteCodes,
                  child: ListView.builder(
                    itemCount: _inviteCodes.length,
                    itemBuilder: (_, i) {
                      final code = _inviteCodes[i] as Map;
                      final codeStr = code['code'] ?? '';
                      final used = code['used_count'] ?? 0;
                      final maxUses = code['max_uses'] ?? 1;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF151B3A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(codeStr.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                                  Text('$used/$maxUses 次',
                                    style: TextStyle(fontSize: 12, color: used >= maxUses ? Colors.red : Colors.green)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 20),
                              onPressed: () async {
                                try {
                                  await ApiService().adminDeleteInviteCode(codeStr.toString());
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('已删除')),
                                    );
                                    _loadInviteCodes();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('删除失败: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B3A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF202124))),
            ],
          ),
        ],
      ),
    );
  }
}
