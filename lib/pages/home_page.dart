import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/l10n_helper.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'settings_page.dart';
import 'favorites_page.dart';
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
            BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline), activeIcon: const Icon(Icons.chat_bubble), label: context.t('chats')),
            BottomNavigationBarItem(icon: const Icon(Icons.contacts_outlined), activeIcon: const Icon(Icons.contacts), label: context.t('contacts')),
            BottomNavigationBarItem(icon: const Icon(Icons.star_border), activeIcon: const Icon(Icons.star), label: context.t('favorites')),
            BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), activeIcon: const Icon(Icons.settings), label: context.t('settings')),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0E23) : const Color(0xFFF5F5F5);
    final sidebarColor = isDark ? const Color(0xFF111432) : const Color(0xFF2B2B2B);
    final selectedColor = const Color(0xFF1AA4EC);

    final pages = [
      ChatListPage(userId: widget.userId),
      ContactsPage(userId: widget.userId),
      FavoritesPage(userId: widget.userId),
      SettingsPage(userId: widget.userId),
    ];

    final navItems = [
      (Icons.chat_bubble_outline, Icons.chat_bubble, context.t('chats')),
      (Icons.contacts_outlined, Icons.contacts, context.t('contacts')),
      (Icons.star_border, Icons.star, context.t('favorites')),
      (Icons.settings_outlined, Icons.settings, context.t('settings')),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // ─── Left sidebar ───────────────────────────────────
          Container(
            width: 68,
            color: sidebarColor,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // App logo / avatar
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1AA4EC), Color(0xFF168CCA)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text('A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
                // Nav icons
                ...List.generate(navItems.length, (i) {
                  final isSelected = _currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Tooltip(
                      message: navItems[i].$3,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _currentIndex = i),
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected ? selectedColor.withAlpha(30) : Colors.transparent,
                            ),
                            child: Icon(
                              isSelected ? navItems[i].$2 : navItems[i].$1,
                              color: isSelected ? selectedColor : (isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                // Settings at bottom
                // (already included above as index 3)
                const SizedBox(height: 16),
              ],
            ),
          ),
          // ─── Content area ──────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}
