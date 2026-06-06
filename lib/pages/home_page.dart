import 'dart:async';
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
}
