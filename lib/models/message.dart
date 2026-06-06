class Message {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;
  final String senderName;
  final MessageType type;
  final bool isRead;
  final bool isDeleted;
  final bool isEdited;
  final bool isEphemeral;
  final int? ephemeralSeconds;
  final String? imageUrl;
  final String? voiceUrl;
  final double? voiceDuration;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;

  const Message({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.senderName = '',
    this.type = MessageType.text,
    this.isRead = false,
    this.isDeleted = false,
    this.isEdited = false,
    this.isEphemeral = false,
    this.ephemeralSeconds,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDuration,
    this.fileUrl,
    this.fileName,
    this.fileSize,
  });

  String get timeString {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (time.day == now.day) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    if (time.day == now.day - 1) return '昨天';
    if (diff.inDays < 7) return ['周一','周二','周三','周四','周五','周六','周日'][time.weekday - 1];
    return '${time.month}月${time.day}日';
  }
}

enum MessageType { text, image, voice, video, file, location, system }
