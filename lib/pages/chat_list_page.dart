import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/mock_data.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';

final _colors = [
  const Color(0xFF1AA4EC), const Color(0xFF52C41A), const Color(0xFFFAAD14),
  const Color(0xFFFF4D4F), const Color(0xFF722ED1), const Color(0xFF13C2C2),
  const Color(0xFFEB2F96), const Color(0xFFFA8C16),
];

Color _getColor(String name) {
  int h = 0;
  for (int i = 0; i < name.length; i++) h = name.codeUnitAt(i) + ((h << 5) - h);
  return _colors[(h.abs() % _colors.length)];
}

/// Convert an API response map to a [ConversationData].
ConversationData _conversationFromMap(Map m) {
  final now = DateTime.now();

  // Support both camelCase and snake_case keys
  String v(String camel, String snake) =>
      (m[camel] ?? m[snake] ?? '') as String;
  int vi(String camel, String snake, [int d = 0]) =>
      ((m[camel] ?? m[snake]) as num?)?.toInt() ?? d;
  bool vb(String camel, String snake) =>
      ((m[camel] ?? m[snake]) as bool?) ?? false;

  // Parse DateTime from string or int (millis)
  DateTime parseTime(dynamic val) {
    if (val == null) return now;
    if (val is String) {
      final dt = DateTime.tryParse(val);
      if (dt != null) return dt;
    }
    if (val is num) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    }
    return now;
  }

  return ConversationData(
    v('id', 'id'),
    v('name', 'name'),
    v('lastMessage', 'last_message'),
    parseTime(m['lastTime'] ?? m['last_time']),
    unread: vi('unreadCount', 'unread_count'),
    online: vb('isOnline', 'is_online') || vb('online', 'online'),
    pinned: vb('isPinned', 'is_pinned') || vb('pinned', 'pinned'),
    isGroup: vb('isGroup', 'is_group') || vb('group', 'group'),
    members: vi('memberCount', 'member_count', 0),
    targetUserId: (m['target_user_id'] as String?) ?? '',
  );
}

class ChatListPage extends StatefulWidget {
  final String? userId;
  final Function(String conversationId, String conversationName, String? targetUserId, bool isGroup, bool online)? onConversationTap;
  const ChatListPage({super.key, this.userId, this.onConversationTap});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _searchCtrl = TextEditingController();
  List<ConversationData> _allConversations = [];
  List<ConversationData> _filteredConversations = [];
  bool _loading = true;
  String? _error;
  bool _searchMode = false;
  List<Map> _globalSearchResults = [];
  bool _searchingMessages = false;

  String get _userId =>
      widget.userId ?? ApiService().currentUserId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadConversations();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredConversations = List.from(_allConversations);
        _globalSearchResults = [];
      } else {
        _filteredConversations = _allConversations
            .where((c) => c.name.toLowerCase().contains(q))
            .toList();
        if (_searchMode) {
          _searchMessages(q);
        }
      }
    });
  }

  Future<void> _searchMessages(String q) async {
    if (q.isEmpty) return;
    setState(() => _searchingMessages = true);
    try {
      final uid = _userId;
      if (uid.isNotEmpty) {
        final results = await ApiService().searchMessages(uid, q);
        if (mounted) {
          setState(() {
            _globalSearchResults = results.map((e) => e as Map).toList();
            _searchingMessages = false;
          });
        }
      } else {
        if (mounted) setState(() => _searchingMessages = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searchingMessages = false);
    }
  }

  void _toggleSearchMode() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchCtrl.clear();
        _globalSearchResults = [];
      }
    });
  }

  void _showFavorites() async {
    try {
      final uid = _userId;
      if (uid.isEmpty) return;
      final result = await ApiService().getFavorites(uid);
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
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
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
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9),
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
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    )),
                  const Spacer(),
                  Text('${favorites.length}条',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
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
                              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                            const SizedBox(height: 8),
                            Text('暂无收藏',
                              style: TextStyle(fontSize: 14,
                                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) => Divider(height: 1,
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                        itemBuilder: (_, i) {
                          final f = favorites[i] as Map;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getColor((f['senderName'] ?? '?').toString()),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  (f['senderName'] ?? '?').toString()[0],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            title: Text(
                              f['text'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF202124),
                              ),
                            ),
                            subtitle: Text(
                              f['senderName'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
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
          const SnackBar(content: Text('加载收藏失败')),
        );
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = _userId;
      if (uid.isEmpty) {
        // Fallback to mock data when no userId is available
        setState(() {
          _allConversations = List.from(MockData.conversations);
          _filteredConversations = List.from(MockData.conversations);
          _loading = false;
        });
        return;
      }

      final raw = await ApiService().getConversations(uid);
      final list = raw
          .map((e) => _conversationFromMap(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _allConversations = list;
        _filteredConversations = List.from(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Fallback to mock data on error
        _allConversations = List.from(MockData.conversations);
        _filteredConversations = List.from(MockData.conversations);
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _Header(
          isDark: isDark,
          searchMode: _searchMode,
          onSearchTap: _toggleSearchMode,
          onFavoritesTap: _showFavorites,
        ),
        _SearchBar(
          ctrl: _searchCtrl,
          isDark: isDark,
          searchMode: _searchMode,
          onCancel: _toggleSearchMode,
        ),
        Expanded(
          child: _buildBody(isDark),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show global search results when in search mode with a query
    if (_searchMode && _globalSearchResults.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('搜索结果',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
              )),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _globalSearchResults.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16,
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
              itemBuilder: (_, i) {
                final msg = _globalSearchResults[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getColor((msg['senderName'] ?? '?').toString()),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                (msg['senderName'] ?? '?').toString()[0],
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF202124),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  msg['senderName'] ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Show "searching..." when in search mode but loading
    if (_searchMode && _searchingMessages && _searchCtrl.text.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show "no results" when in search mode with query but no results
    if (_searchMode && _searchCtrl.text.isNotEmpty && _globalSearchResults.isEmpty && !_searchingMessages) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48,
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
            const SizedBox(height: 8),
            Text('未找到相关消息',
              style: TextStyle(fontSize: 14,
                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
          ],
        ),
      );
    }

    // Normal conversation list
    final pinned = _filteredConversations.where((c) => c.pinned).toList();
    final normal = _filteredConversations.where((c) => !c.pinned).toList();

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (pinned.isNotEmpty) ...[
            _SectionLabel(label: '置顶对话', isDark: isDark),
            ...pinned.map((c) => _ConvTile(c: c, isDark: isDark, userId: _userId, onTap: widget.onConversationTap)),
            Divider(indent: 16, endIndent: 16, height: 1,
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
          ],
          if (normal.isEmpty && pinned.isEmpty)
            _EmptyState(isDark: isDark)
          else
            ...normal.map((c) => _ConvTile(c: c, isDark: isDark, userId: _userId, onTap: widget.onConversationTap)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  final bool searchMode;
  final VoidCallback onSearchTap;
  final VoidCallback onFavoritesTap;
  const _Header({
    required this.isDark,
    required this.searchMode,
    required this.onSearchTap,
    required this.onFavoritesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text('消息', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF202124))),
          const Spacer(),
          _IconBtn(
            searchMode ? Icons.close : Icons.search,
            isDark,
            color: searchMode ? const Color(0xFF1AA4EC) : null,
            onTap: onSearchTap,
          ),
          _IconBtn(Icons.star_border, isDark, color: const Color(0xFFFAAD14), onTap: onFavoritesTap),
          _IconBtn(Icons.edit_outlined, isDark),
          _IconBtn(Icons.more_vert, isDark),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final bool searchMode;
  final VoidCallback onCancel;

  const _SearchBar({
    required this.ctrl,
    required this.isDark,
    this.searchMode = false,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141D4D) : const Color(0xFFF2F5F9),
                borderRadius: BorderRadius.circular(10),
                border: searchMode
                    ? Border.all(color: const Color(0xFF1AA4EC), width: 1)
                    : null,
              ),
              child: TextField(
                controller: ctrl,
                autofocus: searchMode,
                decoration: InputDecoration(
                  hintText: searchMode ? '搜索消息内容...' : '搜索消息、联系人',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
                  prefixIcon: Icon(searchMode ? Icons.message_outlined : Icons.search, size: 18, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
                  suffixIcon: ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            ctrl.clear();
                          },
                          child: Icon(Icons.close, size: 16,
                              color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF202124)),
              ),
            ),
          ),
          if (searchMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCancel,
              child: Text('取消',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF1AA4EC),
                )),
            ),
          ],
        ],
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
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
            const SizedBox(height: 12),
            Text('暂无消息', style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
          ],
        ),
      ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  final ConversationData c;
  final bool isDark;
  final String userId;
  final Function(String conversationId, String conversationName, String? targetUserId, bool isGroup, bool online)? onTap;

  const _ConvTile({required this.c, required this.isDark, required this.userId, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!(c.id, c.name, c.targetUserId, c.isGroup, c.online);
          } else {
            if (c.isGroup) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GroupChatPage(
                userId: userId,
                conversationId: c.id,
                conversationName: c.name,
                online: c.online,
                memberCount: c.members ?? 0,
              )),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatPage(
                userId: userId,
                conversationId: c.id,
                conversationName: c.name,
                isGroup: false,
                online: c.online,
                targetUserId: c.targetUserId,
              )),
            );
          }
        }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9), width: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: _getColor(c.name), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(c.name.isNotEmpty ? c.name[0] : '?', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white))),
                  ),
                  if (c.online)
                    Positioned(
                      right: 1, bottom: 1,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF52C41A), shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF141D4D) : Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (c.pinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin, size: 12, color: Color(0xFF1AA4EC)),
                          ),
                        Expanded(
                          child: Text(c.name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF202124)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(c.timeString, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.lastMessage,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.unread > 99 ? '99+' : c.unread.toString(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
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
  final Color? color;
  final VoidCallback? onTap;
  const _IconBtn(this.icon, this.isDark, {this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34, height: 34, alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color ?? (isDark ? const Color(0xFFB2BAC2) : const Color(0xFF5E5E5E))),
        ),
      ),
    );
  }
}
