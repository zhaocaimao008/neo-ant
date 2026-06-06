import 'dart:math';
import 'dart:ui' show Color;

class Contact {
  final String id;
  final String name;
  final String status;
  final bool isOnline;
  final String group;

  const Contact({
    required this.id,
    required this.name,
    this.status = '在线',
    this.isOnline = true,
    this.group = '其他',
  });
}

class MockData {
  static final _rand = Random();

  static final List<ConversationData> conversations = [
    ConversationData('c1', '陈明', '好的，我确认一下', _t(h: 9, m: 42), unread: 3, online: true, pinned: true),
    ConversationData('c2', '项目A-需求讨论', '王磊: 附件已更新，请查收', _t(h: 9, m: 15), unread: 5, online: true, pinned: true, isGroup: true, members: 12),
    ConversationData('c3', '李华', '收到，谢谢！', _t(y: true), unread: 0, online: false),
    ConversationData('c4', '张伟', '会议纪要已发邮件', _t(y: true), unread: 1, online: true),
    ConversationData('c5', '技术部', '赵工: 部署脚本已更新', _t(y: true), unread: 8, online: true, isGroup: true, members: 18),
    ConversationData('c6', '产品设计组', '刘婷: 新版本原型已上传', _t(d: 3), unread: 2, online: false, isGroup: true, members: 25),
    ConversationData('c7', '王芳', '周末有空吗？', _t(d: 2), unread: 0, online: true),
    ConversationData('c8', '全栈技术交流群', '孙鹏: 这个问题可以看下文档', _t(d: 1), unread: 15, online: false, isGroup: true, members: 156),
    ConversationData('c9', '张三', '好的，明天见！', _t(d: 1), unread: 0, online: true),
    ConversationData('c10', '李四', '文件已经发送了', _t(d: 3, month: true), unread: 0, online: false),
  ];

  static final List<ContactItem> contacts = [
    ContactItem('陈明', '工作沟通中', true, '常用联系人'),
    ContactItem('李华', '在线', true, '常用联系人'),
    ContactItem('王芳', '离线', false, '常用联系人'),
    ContactItem('张伟', '会议中', true, '项目A'),
    ContactItem('刘婷', '在线', true, '项目A'),
    ContactItem('王磊', '离线', false, '项目A'),
    ContactItem('赵强', '忙碌', true, '技术部'),
    ContactItem('孙鹏', '在线', true, '技术部'),
    ContactItem('周杰', '离线', false, '技术部'),
    ContactItem('吴婷', '出差中', true, '其他'),
    ContactItem('郑浩', '在线', true, '其他'),
  ];

  static final List<GroupItem> groups = [
    GroupItem('项目A-需求讨论', '42', true),
    GroupItem('技术部', '18', true),
    GroupItem('产品设计组', '25', false),
    GroupItem('全栈技术交流群', '156', false),
  ];

  static DateTime _t({int h = 0, int m = 0, int? d, bool y = false, bool month = false}) {
    final now = DateTime.now();
    if (month) return now.subtract(const Duration(days: 5));
    if (d != null) return now.subtract(Duration(days: d));
    if (y) return now.subtract(const Duration(days: 1));
    return DateTime(now.year, now.month, now.day, h, m);
  }

  static Color getColor(String name) {
    final colors = [
      Color(0xFF1AA4EC), Color(0xFF52C41A), Color(0xFFFAAD14),
      Color(0xFFFF4D4F), Color(0xFF722ED1), Color(0xFF13C2C2),
      Color(0xFFEB2F96), Color(0xFFFA8C16),
    ];
    int h = 0;
    for (int i = 0; i < name.length; i++) h = name.codeUnitAt(i) + ((h << 5) - h);
    return colors[(h.abs() % colors.length)];
  }
}

class ConversationData {
  final String id, name, lastMessage;
  final DateTime lastTime;
  final int unread;
  final bool online, pinned, isGroup;
  final int? members;
  final String targetUserId;
  const ConversationData(this.id, this.name, this.lastMessage, this.lastTime,
      {this.unread = 0, this.online = false, this.pinned = false,
       this.isGroup = false, this.members, this.targetUserId = ''});

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

class ContactItem {
  final String name, status, group;
  final bool online;
  const ContactItem(this.name, this.status, this.online, this.group);
}

class GroupItem {
  final String name, members;
  final bool online;
  const GroupItem(this.name, this.members, this.online);
}
