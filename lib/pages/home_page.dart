import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'settings_page.dart';
import 'favorites_page.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';
import 'call_page.dart';

class HomePage extends StatefulWidget {
  final String userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  StreamSubscription<Map>? _callSub;

  // Desktop: selected conversation for right panel
  String? _selConvId;
  String _selConvName = '';
  String? _selTargetUserId;
  bool _selIsGroup = false;
  bool _selOnline = false;

  bool get _isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService().connectWs(widget.userId);
    _callSub = ApiService().callStream.listen(_handleIncomingCall);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSub?.cancel();
    super.dispose();
  }

  void _handleIncomingCall(Map msg) {
    if (msg['type'] == 'call:offer' && mounted) {
      final callType = msg['callType'] as String? ?? 'audio';
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CallPage(
          userId: widget.userId,
          targetUserId: msg['fromUserId'] ?? '',
          targetName: msg['fromName'] ?? '未知用户',
          isVideo: callType == 'video',
          isIncoming: true,
          incomingOffer: msg,
        )),
      );
    }
  }

  void _onConversationTap(String convId, String convName, String? targetUserId, bool isGroup, bool online) {
    setState(() {
      _selConvId = convId;
      _selConvName = convName;
      _selTargetUserId = targetUserId;
      _selIsGroup = isGroup;
      _selOnline = online;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isDesktop ? _buildDesktop() : _buildMobile();
  }

  Widget _buildMobile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      ChatListPage(userId: widget.userId),
      ContactsPage(userId: widget.userId),
      FavoritesPage(userId: widget.userId),
      SettingsPage(userId: widget.userId),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0E23) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: isDark ? const Color(0xFF0A0E23) : Colors.white,
          selectedItemColor: const Color(0xFF1AA4EC),
          unselectedItemColor: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), activeIcon: const Icon(Icons.chat_bubble), label: '聊天'),
            BottomNavigationBarItem(icon: const Icon(Icons.contacts_outlined), activeIcon: const Icon(Icons.contacts), label: '通讯录'),
            BottomNavigationBarItem(icon: const Icon(Icons.star_border), activeIcon: const Icon(Icons.star), label: '收藏'),
            BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), activeIcon: const Icon(Icons.settings), label: '设置'),
          ],
        ),
      ),
    );
  }

  // ─── Desktop: Three-column Ant Messenger layout ────────────
  Widget _buildDesktop() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Color scheme matching Ant Messenger dark/light
    final bg = isDark ? const Color(0xFFEDEDED) : const Color(0xFFEDEDED);
    final sidebarBg = const Color(0xFF2E2E2E);
    final panelBg = isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5);
    final contentBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final accent = const Color(0xFF07C160); // Ant green
    final textColor = const Color(0xFF353535);
    final hintColor = const Color(0xFFB2B2B2);
    final dividerColor = const Color(0xFFE6E6E6);
    final activeBg = const Color(0xFFC9E7FF);
    final hoverBg = const Color(0xFFE8E8E8);

    final navIcons = [
      (Icons.chat_bubble_outline, '聊天'),
      (Icons.contacts_outlined, '通讯录'),
      (Icons.star_border, '收藏'),
      (Icons.settings_outlined, '设置'),
    ];

    return Scaffold(
      backgroundColor: contentBg,
      body: Row(
        children: [
          // ─── Left Sidebar (60px) ───────────────────────────
          Container(
            width: 60,
            color: sidebarBg,
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Avatar
                GestureDetector(
                  onTap: () => setState(() => _currentIndex = 3),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF07C160),
                    ),
                    child: Center(
                      child: Text(
                        widget.userId.isNotEmpty ? ApiService().currentUserName.isNotEmpty
                            ? ApiService().currentUserName[0].toUpperCase() : 'A'
                            : 'A',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Nav icons
                ...List.generate(navIcons.length, (i) {
                  final sel = _currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Tooltip(
                      message: navIcons[i].$2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() { _currentIndex = i; _selConvId = null; }),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: sel ? const Color(0xFF07C160).withAlpha(40) : Colors.transparent,
                            ),
                            child: Icon(
                              sel ? Icons.chat_bubble : navIcons[i].$1,
                              color: sel ? const Color(0xFF07C160) : const Color(0xFFAAAAAA),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ─── Middle Panel (300px) ──────────────────────────
          Container(
            width: 300,
            color: panelBg,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                  color: panelBg,
                  child: Row(
                    children: [
                      Text(
                        ['消息', '通讯录', '收藏', '设置'][_currentIndex],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF353535)),
                      ),
                      const Spacer(),
                      if (_currentIndex == 0)
                        Icon(Icons.search, size: 20, color: hintColor),
                      if (_currentIndex == 0)
                        const SizedBox(width: 8),
                      if (_currentIndex == 0)
                        Icon(Icons.add_circle_outline, size: 20, color: hintColor),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      // Chat List - pass callback
                      ChatListPage(
                        userId: widget.userId,
                        onConversationTap: _onConversationTap,
                      ),
                      ContactsPage(userId: widget.userId),
                      FavoritesPage(userId: widget.userId),
                      SizedBox(), // Settings handled differently
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(width: 1, color: dividerColor),

          // ─── Right Panel (Chat/Content) ────────────────────
          Expanded(
            child: _selConvId != null
                ? (_selIsGroup
                    ? GroupChatPage(
                        userId: widget.userId,
                        conversationId: _selConvId!,
                        conversationName: _selConvName,
                        online: _selOnline,
                        memberCount: 0,
                      )
                    : ChatPage(
                        key: ValueKey(_selConvId),
                        userId: widget.userId,
                        conversationId: _selConvId!,
                        conversationName: _selConvName,
                        isGroup: false,
                        online: _selOnline,
                        targetUserId: _selTargetUserId,
                      ))
                : _buildPlaceholder(isDark, contentBg),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark, Color contentBg) {
    return Container(
      color: contentBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF07C160).withAlpha(20),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 40, color: Color(0xFF07C160)),
            ),
            const SizedBox(height: 16),
            const Text(
              '选择聊天开始对话',
              style: TextStyle(fontSize: 14, color: Color(0xFFB2B2B2)),
            ),
          ],
        ),
      ),
    );
  }
}
