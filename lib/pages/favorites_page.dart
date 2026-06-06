import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ant_avatar.dart';
import 'chat_page.dart';

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

class FavoritesPage extends StatefulWidget {
  final String userId;
  const FavoritesPage({super.key, required this.userId});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List _favorites = [];
  bool _loading = true;

  String get _userId => widget.userId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final uid = _userId;
      if (uid.isEmpty) {
        setState(() {
          _favorites = [];
          _loading = false;
        });
        return;
      }
      final result = await ApiService().getFavorites(uid);
      final dynamic raw = result['favorites'];
      final List items = raw is List ? raw : [];
      if (mounted) {
        setState(() {
          _favorites = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _favorites = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(String id) async {
    try {
      await ApiService().removeFavorite(id);
      _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏'), duration: Duration(seconds: 1)),
        );
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.star, size: 22, color: Color(0xFFFAAD14)),
              const SizedBox(width: 8),
              Text('收藏消息', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF202124))),
              const Spacer(),
              Text('${_favorites.length} 条', style: TextStyle(fontSize: 12,
                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_border, size: 48,
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                          const SizedBox(height: 12),
                          Text('暂无收藏', style: TextStyle(fontSize: 14,
                            color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
                          const SizedBox(height: 4),
                          Text('长按消息可选择收藏', style: TextStyle(fontSize: 12,
                            color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9))),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _favorites.length,
                        separatorBuilder: (_, __) => Divider(height: 1,
                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
                        itemBuilder: (_, i) {
                          final f = _favorites[i] as Map;
                          final text = f['text']?.toString() ?? '';
                          final senderName = f['senderName']?.toString() ?? '?';
                          final id = f['id']?.toString() ?? f['_id']?.toString() ?? '';
                          final conversationId = f['conversationId']?.toString() ?? '';

                          return Dismissible(
                            key: Key(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: const Color(0xFFFF3B30),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => _removeFavorite(id),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (conversationId.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ChatPage(
                                        userId: _userId,
                                        conversationId: conversationId,
                                        conversationName: senderName,
                                        isGroup: false,
                                      )),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      AntAvatar(text: senderName.isNotEmpty ? senderName[0] : '?', size: 40),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(senderName,
                                              style: TextStyle(fontSize: 12,
                                                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
                                            const SizedBox(height: 4),
                                            Text(text,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 14,
                                                color: isDark ? Colors.white : const Color(0xFF202124))),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 18, color: Color(0xFFAAAAAA)),
                                    ],
                                  ),
                                ),
                              ),
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
