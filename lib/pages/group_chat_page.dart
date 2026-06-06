import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/ant_avatar.dart';
import '../widgets/bottom_sheets.dart';
import 'profile_page.dart';

class GroupChatPage extends StatefulWidget {
  final String userId;
  final String conversationId;
  final String conversationName;
  final String? groupId;
  final bool online;
  final int memberCount;

  const GroupChatPage({
    super.key,
    required this.userId,
    required this.conversationId,
    required this.conversationName,
    this.groupId,
    this.online = false,
    this.memberCount = 0,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _showSend = false;
  bool _disposed = false;
  bool _loading = true;
  int _onlineCount = 0;

  final _messages = <_GMsg>[];
  String _lastDraftContent = '';
  Timer? _draftSaveTimer;
  StreamSubscription<Map>? _msgSub;

  // Emoji list
  static const _emojis = [
    '😀','😁','😂','🤣','😃','😄','😅','😆','😉','😊',
    '😋','😎','😍','🥰','😘','😜','🤪','😝','🤑','🤗',
    '🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒',
    '🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒',
    '🤕','🤢','🤮','🥵','🥶','🥴','😵','🤯','🤠','🥳',
    '🥺','😢','😭','😤','😡','🤬','👋','🤚','🖐','✋',
    '👌','🤌','🤏','✌','🤞','🤟','🤘','🤙','👈','👉',
    '👍','👎','👊','✊','🤛','🤜','👏','🙌','👐','🤲',
    '🤝','🙏','💪','❤','🧡','💛','💚','💙','💜','🖤',
    '🔥','⭐','🎉','🎊','🎈','🎁','🎂','🎀','💯','✅',
  ];

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      setState(() => _showSend = _inputCtrl.text.trim().isNotEmpty);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _loadMessages();
    _loadOnlineCount();
    _loadDraft();

    // Auto-save draft when text changes (debounced)
    _inputCtrl.addListener(_onGroupInputChanged);

    // Listen for WS messages via stream
    _msgSub = ApiService().messageStream.listen((msg) {
      if (!_disposed && msg['conversation_id'] == widget.conversationId) {
        setState(() {
          _messages.add(_GMsg(
            msg['text'] ?? '',
            msg['sender_id'] == widget.userId,
            DateTime.parse(msg['created_at'] ?? DateTime.now().toIso8601String()),
            id: msg['id']?.toString(),
            isImage: msg['type'] == 'image',
            imagePath: msg['file_url'],
            sender: msg['sender_name'],
            read: true,
          ));
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_disposed) _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _saveDraft();
    _draftSaveTimer?.cancel();
    _msgSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineCount() async {
    try {
      final gid = widget.groupId ?? widget.conversationId;
      final members = await ApiService().getGroupMembers(gid);
      if (!_disposed) {
        setState(() => _onlineCount = members.length);
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService().getMessages(widget.conversationId);
      if (_disposed) return;
      setState(() {
        _messages.clear();
        for (final m in data) {
          _messages.add(_GMsg(
            m['text'] ?? '',
            m['sender_id'] == widget.userId,
            DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
            id: m['id']?.toString(),
            isImage: m['type'] == 'image',
            imagePath: m['file_url'],
            sender: m['sender_name'],
            read: true,
          ));
        }
        _loading = false;
      });
      Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
    } catch (_) {
      if (!_disposed) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── Draft ──────────────────────────────────────────────────
  Future<void> _loadDraft() async {
    try {
      final data = await ApiService().getDraft(widget.userId, widget.conversationId);
      if (_disposed) return;
      if (data['content'] != null && data['content'].toString().isNotEmpty) {
        _inputCtrl.text = data['content'];
      }
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    if (_disposed) return;
    final content = _inputCtrl.text;
    if (content == _lastDraftContent) return; // Skip if unchanged
    if (content.isEmpty) {
      _lastDraftContent = content;
      return; // Don't save empty drafts
    }
    _lastDraftContent = content;
    try {
      await ApiService().saveDraft(widget.userId, widget.conversationId, content);
    } catch (_) {}
  }

  void _onGroupInputChanged() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 2), _saveDraft);
  }

  // ─── Send ───────────────────────────────────────────────────
  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final msg = _GMsg(text, true, DateTime.now(), read: true);
    setState(() {
      _messages.add(msg);
      _inputCtrl.clear();
    });

    ApiService().sendWsMessage({
      'type': 'message',
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'text': text,
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_disposed) _scrollToBottom();
    });
  }

  // ─── Image Picker ───────────────────────────────────────────
  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) {
      try {
        final result = await ApiService().sendMessage(
          widget.conversationId, widget.userId, '',
          type: 'image', filePath: file.path,
        );
        setState(() {
          _messages.add(_GMsg(
            '', true, DateTime.now(), read: true,
            isImage: true, imagePath: result['file_url'] ?? file.path,
            id: result['id']?.toString(),
          ));
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_disposed) _scrollToBottom();
        });
      } catch (_) {}
    }
  }

  // ─── Emoji Picker ───────────────────────────────────────────
  void _showEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D4D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _emojis.length,
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () {
                    _inputCtrl.text += _emojis[i];
                    Navigator.pop(ctx);
                    _focusNode.requestFocus();
                  },
                  child: Center(child: Text(_emojis[i], style: const TextStyle(fontSize: 24))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Invite Member ──────────────────────────────────────────
  void _showInviteDialog() {
    final usernameCtrl = TextEditingController();
    final gid = widget.groupId ?? widget.conversationId ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请成员'),
        content: TextField(
          controller: usernameCtrl,
          decoration: const InputDecoration(
            labelText: '成员账号',
            hintText: '输入要邀请的成员账号',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim();
              if (username.isNotEmpty) {
                try {
                  await ApiService().inviteGroupMember(gid, widget.userId, username);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('邀请已发送')),
                    );
                    _loadOnlineCount();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('邀请失败: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('发送邀请'),
          ),
        ],
      ),
    );
  }

  // ─── Show Group Info ────────────────────────────────────────
  void _showGroupInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(
        name: widget.conversationName,
        isGroup: true,
        memberCount: _onlineCount,
        userId: widget.userId,
        conversationId: widget.conversationId,
        groupId: widget.groupId ?? widget.conversationId,
      )),
    );
  }

  // ─── Delete Message ─────────────────────────────────────────
  void _deleteMsg(int index) {
    final id = _messages[index].id;
    setState(() => _messages.removeAt(index));
    if (id != null && id.isNotEmpty) {
      ApiService().deleteMessage(id, widget.conversationId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _onMsgTap(int index, _GMsg msg) {
    showMessageActions(context, isMe: msg.isMe,
      onCopy: () => Clipboard.setData(ClipboardData(text: msg.text)),
      onReply: () {},
      onDelete: () => _deleteMsg(index),
      onFavorite: () => _favoriteMsg(msg),
      onForward: () => _forwardMsg(msg),
    );
  }

  void _favoriteMsg(_GMsg msg) {
    ApiService().addFavorite(
      widget.userId, msg.id ?? '', widget.conversationId, msg.text, msg.sender ?? '',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已收藏'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _forwardMsg(_GMsg msg) async {
    try {
      final conversations = await ApiService().getConversations(widget.userId);
      if (!mounted || _disposed) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final target = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('选择转发目标', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124))),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (ctx, i) {
                      final conv = conversations[i];
                      final name = conv['name'] ?? conv['id'];
                      return ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: Text(name.toString(), style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF202124))),
                        onTap: () => Navigator.pop(ctx, conv['id']?.toString()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (target != null && target.isNotEmpty && !_disposed) {
        final type = msg.isImage ? 'image' : 'text';
        final fileUrl = msg.imagePath ?? '';
        await ApiService().forwardMessage(widget.userId, target, msg.text, type, fileUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已转发'), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xE0101631) : const Color(0xE0FFFFFF),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF4A4A4A) : const Color(0xFF5E5E5E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            AntAvatar(text: widget.conversationName, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.conversationName,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124))),
                Text('$_onlineCount 人 在线',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF52C41A))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.star_border, size: 20,
            color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFF5E5E5E)), onPressed: _showFavorites),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20,
              color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFF5E5E5E)),
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
            onSelected: (value) {
              if (value == 'invite') {
                _showInviteDialog();
              } else if (value == 'info') {
                _showGroupInfo();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1, size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF202124)),
                    const SizedBox(width: 8),
                    Text('邀请成员',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF202124))),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF202124)),
                    const SizedBox(width: 8),
                    Text('群聊信息',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF202124))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 48,
                              color: Color(0xFFE9E9E9)),
                            const SizedBox(height: 12),
                            Text('开始群聊',
                              style: TextStyle(fontSize: 14,
                                color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showInviteDialog,
                              icon: const Icon(Icons.group_add, size: 18),
                              label: const Text('邀请成员'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1AA4EC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildMessageList(isDark),
          ),
          // Input area
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Future<void> _showFavorites() async {
    try {
      final data = await ApiService().getFavorites(widget.userId);
      if (!mounted || _disposed) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dynamic raw = data['favorites'];
      final List items = raw is List ? raw : [];
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D4D) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('收藏消息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF202124))),
                ),
                const Divider(height: 1),
                items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('暂无收藏', style: TextStyle(color: Color(0xFFAAAAAA))),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (ctx, i) {
                            final item = items[i] is Map ? items[i] as Map : <String, dynamic>{};
                            return ListTile(
                              leading: const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                              title: Text(item['text']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF202124))),
                              subtitle: Text(item['senderName']?.toString() ?? '',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _GDateSeparator(date: '今天', isDark: isDark);
        }
        final msg = _messages[i - 1];
        return _GMessageWidget(
          msg: msg,
          index: i - 1,
          isDark: isDark,
          onTap: () => _onMsgTap(i - 1, msg),
        );
      },
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D4D) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_showSend) ...[
                IconButton(icon: Icon(Icons.emoji_emotions_outlined, size: 20,
                  color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)), onPressed: _showEmojiPicker, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
                IconButton(icon: Icon(Icons.image_outlined, size: 20,
                  color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)), onPressed: _pickImage, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
              ],
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF080C25) : const Color(0xFFF2F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF202124)),
                  ),
                ),
              ),
              if (_showSend)
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1AA4EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, size: 16, color: Colors.white),
                    onPressed: _send,
                  ),
                )
              else
                Container(
                  width: 38, height: 38,
                  child: Icon(Icons.mic_none, size: 20,
                    color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data class ─────────────────────────────────────────────────
class _GMsg {
  final String? id;
  final String text;
  final bool isMe;
  final DateTime time;
  final bool read;
  final bool isImage;
  final String? imagePath;
  final String? sender;

  _GMsg(this.text, this.isMe, this.time,
      {this.id, this.read = false, this.isImage = false, this.imagePath, this.sender});
}

// ─── Date Separator ─────────────────────────────────────────────
class _GDateSeparator extends StatelessWidget {
  final String date;
  final bool isDark;
  const _GDateSeparator({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D4D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(date, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFB2BAC2) : const Color(0xFFAAAAAA))),
      ),
    );
  }
}

// ─── Message Widget ─────────────────────────────────────────────
class _GMessageWidget extends StatelessWidget {
  final _GMsg msg;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _GMessageWidget({
    required this.msg, required this.index, required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showSender = !msg.isMe && (msg.sender != null && msg.sender!.isNotEmpty);

    return GestureDetector(
      onLongPress: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Other's avatar
            if (!msg.isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 16),
                child: AntAvatar(text: msg.sender ?? '?', size: 30),
              ),
            // Bubble + content
            Flexible(
              child: Column(
                crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showSender)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 4),
                      child: Text(msg.sender!, style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                    ),
                  if (msg.isImage && msg.imagePath != null)
                    _GImageBubble(path: msg.imagePath!, isMe: msg.isMe, isDark: isDark)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                      decoration: BoxDecoration(
                        color: msg.isMe ? const Color(0xFF1AA4EC) : (isDark ? const Color(0xFF141D4D) : Colors.white),
                        borderRadius: msg.isMe
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4))
                            : const BorderRadius.only(
                                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(14)),
                        boxShadow: msg.isMe ? [] : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      child: Text(msg.text,
                        style: TextStyle(fontSize: 14, color: msg.isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF202124))),
                      ),
                    ),
                ],
              ),
            ),
            // Read status for own messages
            if (msg.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Icon(
                  msg.read ? Icons.done_all : Icons.done,
                  size: 14, color: msg.read ? const Color(0xFF1AA4EC) : const Color(0xFFAAAAAA),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Image Bubble ───────────────────────────────────────────────
class _GImageBubble extends StatelessWidget {
  final String path;
  final bool isMe;
  final bool isDark;
  const _GImageBubble({required this.path, required this.isMe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55, maxHeight: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE9E9E9)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48)),
    );
  }
}
