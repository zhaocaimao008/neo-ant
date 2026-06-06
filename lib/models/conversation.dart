class Conversation {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final bool isOnline;
  final bool isPinned;
  final bool isGroup;
  final String? avatarText;
  final int memberCount;

  const Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isPinned = false,
    this.isGroup = false,
    this.avatarText,
    this.memberCount,
  });

  String get timeString {
    final now = DateTime.now();
    final diff = now.difference(lastTime);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (lastTime.day == now.day) {
      return '${lastTime.hour.toString().padLeft(2, '0')}:${lastTime.minute.toString().padLeft(2, '0')}';
    }
    if (lastTime.day == now.day - 1) return '昨天';
    if (diff.inDays < 7) return ['周一','周二','周三','周四','周五','周六','周日'][lastTime.weekday - 1];
    return '${lastTime.month}月${lastTime.day}日';
  }
}
