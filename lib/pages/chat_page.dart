import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../widgets/bottom_sheets.dart';
import '../widgets/ant_avatar.dart';
import '../widgets/image_preview.dart';
import 'call_page.dart';
import 'dart:async';

class ChatPage extends StatefulWidget {
  final String userId;
  final String conversationId;
  final String conversationName;
  final bool isGroup;
  final bool online;
  final String? targetUserId; // 1-on-1 conversation partner ID

  const ChatPage({
    super.key,
    required this.userId,
    required this.conversationId,
    required this.conversationName,
    this.isGroup = false,
    this.online = false,
    this.targetUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  bool _showSend = false;
  bool _isRecording = false;
  bool _typing = false;
  int _replyToIndex = -1;
  bool _disposed = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  // Multi-select mode
  bool _selectMode = false;
  final Set<int> _selected = {};

  final _messages = <_Msg>[];
  String _lastDraftContent = '';
  Timer? _draftSaveTimer;
  Timer? _typingTimer;
  StreamSubscription<Map>? _msgSub;
  StreamSubscription<Map>? _typingSub;

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
      _sendTypingDebounced();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _loadMessages();
    _loadDraft();
    _scrollCtrl.addListener(_onScroll);

    // Typing indicator via stream
    _typingSub = ApiService().typingStream.listen((data) {
      if (!_disposed && data['conversation_id'] == widget.conversationId && data['sender_id'] != widget.userId) {
        setState(() => _typing = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (!_disposed) setState(() => _typing = false);
        });
      }
    });

    // Auto-save draft when text changes (debounced)
    _inputCtrl.addListener(_onInputChanged);

    // Real-time messages via stream
    _msgSub = ApiService().messageStream.listen((msg) {
      if (_disposed) return;
      // Handle message deletion
      if (msg['type'] == 'message:deleted') {
        if (msg['conversation_id'] == widget.conversationId) {
          final deletedId = msg['message_id']?.toString();
          if (deletedId != null && deletedId.isNotEmpty) {
            setState(() {
              // Mark as recalled instead of removing
              final idx = _messages.indexWhere((m) => m.id == deletedId);
              if (idx >= 0 && _messages[idx].isMe) {
                _messages[idx] = _Msg(
                  '已撤回', _messages[idx].isMe, _messages[idx].time,
                  id: deletedId, read: true, recalled: true,
                  sender: _messages[idx].sender,
                );
              }
            });
          }
        }
        return;
      }
      if (msg['conversation_id'] == widget.conversationId) {
        // Handle read receipt messages
        if (msg['type'] == 'read_receipt') {
          final readSenderId = msg['sender_id']?.toString();
          if (readSenderId != null) {
            setState(() {
              for (int i = 0; i < _messages.length; i++) {
                if (!_messages[i].isMe && _messages[i].id != null) {
                  _messages[i] = _Msg(
                    _messages[i].text, _messages[i].isMe, _messages[i].time,
                    id: _messages[i].id, read: true,
                    isImage: _messages[i].isImage, imagePath: _messages[i].imagePath,
                    isVoice: _messages[i].isVoice, voicePath: _messages[i].voicePath,
                    duration: _messages[i].duration,
                    isFile: _messages[i].isFile, fileName: _messages[i].fileName,
                    fileSize: _messages[i].fileSize, fileUrl: _messages[i].fileUrl,
                    sender: _messages[i].sender, recalled: _messages[i].recalled,
                    replyToId: _messages[i].replyToId, replyText: _messages[i].replyText,
                    replySender: _messages[i].replySender,
                  );
                }
              }
            });
          }
          return;
        }
        // Determine if this is a message we sent (already in list)
        final existingIdx = _messages.indexWhere((m) => m.id?.toString() == msg['id']?.toString());
        if (existingIdx >= 0) return;

        // Extract reply info
        String? replyToId = msg['reply_to']?.toString();
        String? replyText = msg['reply_text']?.toString();
        String? replySender = msg['reply_sender_name']?.toString();

        final isFromMe = msg['sender_id'] == widget.userId;

        // Auto send read receipt to sender if message is from someone else
        if (!isFromMe && widget.targetUserId != null) {
          ApiService().sendWsMessage({
            'type': 'read_receipt',
            'conversation_id': widget.conversationId,
            'sender_id': widget.userId,
            'target_sender_id': msg['sender_id']?.toString(),
          });
        }

        setState(() {
          _messages.add(_Msg(
            msg['text'] ?? '',
            isFromMe,
            DateTime.parse(msg['created_at'] ?? DateTime.now().toIso8601String()),
            id: msg['id']?.toString(),
            isImage: msg['type'] == 'image',
            imagePath: msg['file_url'],
            isVoice: msg['type'] == 'voice',
            voicePath: msg['file_url'],
            duration: msg['duration'],
            isFile: msg['type'] == 'file',
            fileName: msg['file_name'],
            fileSize: msg['file_size'],
            sender: msg['sender_name'],
            read: isFromMe, // Own messages start as read
            recalled: msg['recalled'] == 1 || msg['recalled'] == true,
            replyToId: replyToId,
            replyText: replyText,
            replySender: replySender,
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
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels <= 50 && !_loadingMore && _hasMore && !_loading && _messages.isNotEmpty) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldestId = _messages.first.id;
      final data = await ApiService().getMessages(widget.conversationId, before: oldestId, limit: 50);
      if (_disposed) return;
      if (data.isEmpty) {
        _hasMore = false;
      } else {
        setState(() {
          for (final m in data.reversed) {
            final isRecalled = m['recalled'] == 1 || m['recalled'] == true;
            _messages.insert(0, _Msg(
              isRecalled ? '已撤回' : (m['text'] ?? ''),
              m['sender_id'] == widget.userId,
              DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
              id: m['id']?.toString(),
              isImage: m['type'] == 'image',
              imagePath: m['file_url'],
              isVoice: m['type'] == 'voice',
              voicePath: m['file_url'],
              duration: m['duration'],
              isFile: m['type'] == 'file',
              fileName: m['file_name'],
              fileSize: m['file_size'],
              sender: m['sender_name'],
              read: true,
              recalled: isRecalled,
              replyToId: m['reply_to']?.toString(),
              replyText: m['reply_text']?.toString(),
              replySender: m['reply_sender_name']?.toString(),
            ));
          }
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (!_disposed) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService().getMessages(widget.conversationId);
      if (_disposed) return;
      setState(() {
        _messages.clear();
        for (final m in data) {
          final isRecalled = m['recalled'] == 1 || m['recalled'] == true;
          _messages.add(_Msg(
            isRecalled ? '已撤回' : (m['text'] ?? ''),
            m['sender_id'] == widget.userId,
            DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
            id: m['id']?.toString(),
            isImage: m['type'] == 'image',
            imagePath: m['file_url'],
            isVoice: m['type'] == 'voice',
            voicePath: m['file_url'],
            duration: m['duration'],
            isFile: m['type'] == 'file',
            fileName: m['file_name'],
            fileSize: m['file_size'],
            sender: m['sender_name'],
            read: true,
            recalled: isRecalled,
            replyToId: m['reply_to']?.toString(),
            replyText: m['reply_text']?.toString(),
            replySender: m['reply_sender_name']?.toString(),
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

  void _onInputChanged() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 2), _saveDraft);
  }

  // ─── Typing ─────────────────────────────────────────────────
  void _sendTypingDebounced() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 1), () {
      if (!_disposed) {
        ApiService().sendTyping(widget.conversationId, widget.userId);
      }
    });
  }

  // ─── Voice Recording ────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || _disposed) return;
    final path = '/tmp/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null || path.isEmpty || _disposed) return;

    try {
      final result = await ApiService().sendMessage(
        widget.conversationId, widget.userId, '',
        type: 'voice', filePath: path,
      );
      if (_disposed) return;
      setState(() {
        _messages.add(_Msg(
          '', true, DateTime.now(), read: true,
          isVoice: true, voicePath: result['file_url'] ?? path,
          duration: 1, // duration not available on web
          id: result['id']?.toString(),
        ));
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_disposed) _scrollToBottom();
      });
    } catch (_) {}
  }

  // ─── Send ───────────────────────────────────────────────────
  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    String? replyToId;
    if (_replyToIndex >= 0 && _replyToIndex < _messages.length) {
      replyToId = _messages[_replyToIndex].id;
    }

    final msg = _Msg(text, true, DateTime.now(), read: true);
    setState(() {
      _messages.add(msg);
      _inputCtrl.clear();
      _replyToIndex = -1;
    });

    final wsMsg = {
      'type': 'message',
      'conversation_id': widget.conversationId,
      'sender_id': widget.userId,
      'text': text,
    };
    if (replyToId != null && replyToId.isNotEmpty) {
      wsMsg['reply_to'] = replyToId;
    }
    ApiService().sendWsMessage(wsMsg);

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
          _messages.add(_Msg(
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

  // ─── File Picker ────────────────────────────────────────────
  Future<void> _pickFile() async {
    if (!mounted) return;
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final uploadResult = await ApiService().sendMessage(
            widget.conversationId, widget.userId, '',
            type: 'file', filePath: file.path,
          );
          if (mounted) {
            setState(() {
              _messages.add(_Msg(
                '', true, DateTime.now(), read: true,
                isFile: true, fileName: file.name, fileSize: file.size,
                id: uploadResult['id']?.toString(),
              ));
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!_disposed) _scrollToBottom();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件发送失败: $e')),
        );
      }
    }
  }

  void _showEmojiPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E254A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
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

  void _onMsgTap(int index, _Msg msg) {
    if (_selectMode) {
      setState(() {
        if (_selected.contains(index)) {
          _selected.remove(index);
          if (_selected.isEmpty) _selectMode = false;
        } else {
          _selected.add(index);
        }
      });
      return;
    }

    if (msg.recalled) return;

    setState(() => _replyToIndex = index);
    final now = DateTime.now();
    final diff = now.difference(msg.time);
    final canRecall = msg.isMe && diff.inMinutes < 2 && !msg.recalled;
    showMessageActions(context, isMe: msg.isMe,
      onCopy: () => _copyMsg(msg.text),
      onReply: () => _focusNode.requestFocus(),
      onDelete: () => _deleteMsg(index),
      onFavorite: () => _favoriteMsg(msg),
      onForward: () => _forwardMsg(msg),
      onRecall: canRecall ? () => _recallMsg(index, msg) : null,
    );
  }

  void _copyMsg(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _favoriteMsg(_Msg msg) {
    ApiService().addFavorite(
      widget.userId, msg.id ?? '', widget.conversationId, msg.text, msg.sender ?? '',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已收藏'), duration: const Duration(seconds: 1)),
      );
    }
  }

  Future<void> _forwardMsg(_Msg msg) async {
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
            color: isDark ? const Color(0xFF1E254A) : Colors.white,
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
                    color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('转发到', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
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
        final type = msg.isImage ? 'image' : (msg.isVoice ? 'voice' : (msg.isFile ? 'file' : 'text'));
        final fileUrl = msg.imagePath ?? msg.voicePath ?? '';
        await ApiService().forwardMessage(widget.userId, target, msg.text, type, fileUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已转发'), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (_) {}
  }

  void _deleteMsg(int index) {
    final id = _messages[index].id;
    setState(() => _messages.removeAt(index));
    if (_replyToIndex == index) _replyToIndex = -1;
    if (id != null && id.isNotEmpty) {
      ApiService().deleteMessage(id, widget.conversationId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _recallMsg(int index, _Msg msg) {
    final id = msg.id;
    if (id == null || id.isEmpty) return;
    // Use delete API to recall — backend will broadcast message:deleted
    ApiService().deleteMessage(id, widget.conversationId);
    setState(() {
      _messages[index] = _Msg(
        '已撤回', msg.isMe, msg.time,
        id: id,
        read: true,
        recalled: true,
        sender: msg.sender,
        replyToId: msg.replyToId,
        replyText: msg.replyText,
        replySender: msg.replySender,
      );
    });
    if (_replyToIndex == index) _replyToIndex = -1;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已撤回'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _batchDelete() {
    final indices = _selected.toList()..sort((a, b) => b - a);
    final ids = indices.map((i) => _messages[i].id).where((id) => id != null && id.isNotEmpty).cast<String>().toList();
    setState(() {
      for (final i in indices) _messages.removeAt(i);
      _selectMode = false;
      _selected.clear();
    });
    for (final id in ids) {
      ApiService().deleteMessage(id, widget.conversationId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${indices.length} 条'), duration: const Duration(seconds: 1)),
    );
  }

  void _setReply(int index) {
    if (_selectMode) return;
    setState(() => _replyToIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050810) : const Color(0xFFF5F7FA),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          // Multi-select mode bar
          if (_selectMode)
            Container(
              color: isDark ? const Color(0xE0111735) : const Color(0xE0FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('已选择 ${_selected.length} 条',
                    style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _batchDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text('删除'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
                  ),
                  TextButton(
                    onPressed: () => setState(() { _selectMode = false; _selected.clear(); }),
                    child: Text('取消'),
                  ),
                ],
              ),
            ),
          // Reply indicator
          if (!_selectMode && _replyToIndex >= 0 && _replyToIndex < _messages.length)
            _ReplyBar(
              msg: _messages[_replyToIndex],
              onCancel: () => setState(() => _replyToIndex = -1),
              isDark: isDark,
            ),
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48,
                              color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
                            const SizedBox(height: 12),
                            Text('暂无消息', style: TextStyle(fontSize: 14,
                              color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
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

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xE0111735) : const Color(0xE0FFFFFF),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF5A6180) : const Color(0xFF5E5E5E)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          GestureDetector(
            onLongPress: () => setState(() { _selectMode = true; _selected.clear(); }),
            child: AntAvatar(text: widget.conversationName, size: 36, showOnline: widget.online),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.conversationName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF202124))),
              Text(_typing ? '正在输入...' : (widget.online ? '在线' : '离线'),
                style: TextStyle(fontSize: 11, color: _typing ? const Color(0xFF1AA4EC) : const Color(0xFF52C41A))),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.star_border, size: 20,
            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF5E5E5E)),
          onPressed: _showFavorites,
        ),
        if (!widget.isGroup) ...[
          IconButton(icon: Icon(Icons.phone_outlined, size: 20,
            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF5E5E5E)), onPressed: () => _startCall(false)),
          IconButton(icon: Icon(Icons.videocam_outlined, size: 20,
            color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF5E5E5E)), onPressed: () => _startCall(true)),
        ],
        IconButton(icon: Icon(Icons.more_vert, size: 20,
          color: isDark ? const Color(0xFF8E95A8) : const Color(0xFF5E5E5E)), onPressed: () {}),
      ],
    );
  }

  void _startCall(bool isVideo) {
    if (widget.targetUserId == null || widget.targetUserId!.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CallPage(
        userId: widget.userId,
        targetUserId: widget.targetUserId!,
        targetName: widget.conversationName,
        isVideo: isVideo,
      )),
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
            color: isDark ? const Color(0xFF1E254A) : Colors.white,
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
                    color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('收藏消息', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
                ),
                const Divider(height: 1),
                items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('暂无收藏', style: TextStyle(color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
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
      itemCount: _messages.length + 1 + (_loadingMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Column(
            children: [
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              _DateSeparator(date: '今天', isDark: isDark),
            ],
          );
        }
        final msgIndex = i - 1 - (_loadingMore ? 1 : 0);
        if (msgIndex < 0 || msgIndex >= _messages.length) return const SizedBox.shrink();
        final msg = _messages[msgIndex];
        final selected = _selected.contains(msgIndex);
        return _MessageWidget(
          msg: msg,
          index: msgIndex,
          isDark: isDark,
          selectMode: _selectMode,
          selected: selected,
          onTap: () => _onMsgTap(msgIndex, msg),
          onDoubleTap: () => _setReply(msgIndex),
        );
      },
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E254A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_showSend) ...{
                IconButton(icon: Icon(Icons.emoji_emotions_outlined, size: 20,
                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)), onPressed: _showEmojiPicker, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
                IconButton(icon: Icon(Icons.attach_file_outlined, size: 20,
                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)), onPressed: _pickFile, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
                IconButton(icon: Icon(Icons.image_outlined, size: 20,
                  color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)), onPressed: _pickImage, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
              },
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF111630) : const Color(0xFFF2F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  child: Container(
                    width: _isRecording ? 80 : 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isRecording ? const Color(0xFFFF3B30) : Colors.transparent,
                      borderRadius: BorderRadius.circular(_isRecording ? 19 : 10),
                      boxShadow: _isRecording
                          ? [BoxShadow(color: const Color(0xFFFF3B30).withAlpha(80), blurRadius: 8, spreadRadius: 1)]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 20,
                          color: _isRecording ? Colors.white : (isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                        if (_isRecording) SizedBox(width: 4),
                        if (_isRecording)
                          const Text('录音中...', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Voice Bubble ────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  final String path;
  final int? duration;
  final bool isMe;
  final bool isDark;
  const _VoiceBubble({required this.path, this.duration, required this.isMe, required this.isDark});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _disposedVoice = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (!_disposedVoice && mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _disposedVoice = true;
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      if (!_disposedVoice) setState(() => _playing = false);
    } else {
      final url = widget.path.startsWith('http') ? widget.path : '${ApiService.baseUrl}/uploads/${widget.path.replaceAll('/uploads/', '')}';
      await _player.play(UrlSource(url));
      if (!_disposedVoice) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durText = widget.duration != null ? '${widget.duration}s' : '◆';
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe ? const Color(0xFF1AA4EC) : (widget.isDark ? const Color(0xFF1E254A) : Colors.white),
          borderRadius: widget.isMe
              ? const BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4))
              : const BorderRadius.only(
                  topLeft: Radius.circular(14), topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4), bottomRight: Radius.circular(14)),
          boxShadow: widget.isMe ? [] : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_playing ? Icons.pause : Icons.play_arrow, size: 20,
              color: widget.isMe ? Colors.white : (widget.isDark ? Colors.white : const Color(0xFF202124))),
            const SizedBox(width: 8),
            Container(
              width: 60, height: 20,
              child: CustomPaint(
                size: const Size(60, 20),
                painter: _WaveformPainter(color: widget.isMe ? Colors.white70 : (widget.isDark ? Colors.white70 : const Color(0xFF202124).withAlpha(100))),
              ),
            ),
            const SizedBox(width: 8),
            Text(durText, style: TextStyle(fontSize: 12,
              color: widget.isMe ? Colors.white70 : (widget.isDark ? Colors.white70 : const Color(0xFF202124))),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final count = 12;
    final spacing = size.width / count;
    for (int i = 0; i < count; i++) {
      final height = 4 + (i % 7) * 2.5;
      final x = i * spacing + spacing / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── File Bubble ──────────────────────────────────────────────────
class _FileBubble extends StatelessWidget {
  final String? fileName;
  final int? fileSize;
  final bool isMe;
  final bool isDark;
  final String? fileUrl;
  const _FileBubble({this.fileName, this.fileSize, this.fileUrl, required this.isMe, required this.isDark});

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (fileUrl != null && fileUrl!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件: $fileName'), duration: const Duration(seconds: 2)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1AA4EC) : (isDark ? const Color(0xFF1E254A) : Colors.white),
        borderRadius: isMe
            ? const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4))
            : const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(14)),
        boxShadow: isMe ? [] : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 20,
            color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF202124))),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fileName ?? '文件', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13,
                  color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF202124))),
              ),
              Text(_formatSize(fileSize),
                style: TextStyle(fontSize: 11,
                  color: isMe ? Colors.white70 : (isDark ? Colors.white70 : const Color(0xFFAAAAAA))),
              ),
            ],
          ),
        ],
      ),
      ),
      );
      }
      }


      // ─── Data ──────────────────────────────────────────────────────
      class _Msg {
  final String? id;
  final String text;
  final bool isMe;
  final DateTime time;
  final bool read;
  final bool isImage;
  final String? imagePath;
  final String? sender;
  final bool isVoice;
  final String? voicePath;
  final int? duration;
  final bool isFile;
  final String? fileName;
  final int? fileSize;
  final bool recalled;
  final String? replyToId;
  final String? replyText;
  final String? replySender;
  final String? fileUrl;

  _Msg(this.text, this.isMe, this.time,
      {this.id, this.read = false, this.isImage = false, this.imagePath, this.sender,
       this.isVoice = false, this.voicePath, this.duration,
       this.isFile = false, this.fileName, this.fileSize, this.fileUrl,
       this.recalled = false,
       this.replyToId, this.replyText, this.replySender});
}

// ─── Widgets ───────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String date;
  final bool isDark;
  const _DateSeparator({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E254A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(date, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
      ),
    );
  }
}

class _MessageWidget extends StatelessWidget {
  final _Msg msg;
  final int index;
  final bool isDark;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _MessageWidget({
    required this.msg, required this.index, required this.isDark,
    required this.selectMode, required this.selected,
    required this.onTap, required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final showSender = !msg.isMe && (msg.sender != null && msg.sender!.isNotEmpty);

    return GestureDetector(
      onLongPress: msg.recalled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Selection checkbox
            if (selectMode && msg.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 4),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20, color: selected ? const Color(0xFF1AA4EC) : const Color(0xFFAAAAAA),
                ),
              ),
            // Other's avatar
            if (!msg.isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 16),
                child: AntAvatar(text: msg.sender ?? '?', size: 30),
              ),
            if (!msg.isMe && selectMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, right: 4),
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 20, color: selected ? const Color(0xFF1AA4EC) : const Color(0xFFAAAAAA),
                ),
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
                  if (msg.recalled)
                    _buildRecalledBubble()
                  else if (msg.replyToId != null && msg.replyToId!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildReplyQuote(),
                        if (msg.isImage && msg.imagePath != null)
                          _ImageBubble(path: msg.imagePath!, isMe: msg.isMe, isDark: isDark)
                        else if (msg.isVoice && msg.voicePath != null)
                          _VoiceBubble(path: msg.voicePath!, duration: msg.duration, isMe: msg.isMe, isDark: isDark)
                        else if (msg.isFile)
                          _FileBubble(fileName: msg.fileName, fileSize: msg.fileSize, fileUrl: msg.fileUrl, isMe: msg.isMe, isDark: isDark)
                        else
                          _TextBubble(text: msg.text, isMe: msg.isMe, isDark: isDark),
                      ],
                    )
                  else if (msg.isImage && msg.imagePath != null)
                    _ImageBubble(path: msg.imagePath!, isMe: msg.isMe, isDark: isDark)
                  else if (msg.isVoice && msg.voicePath != null)
                    _VoiceBubble(path: msg.voicePath!, duration: msg.duration, isMe: msg.isMe, isDark: isDark)
                  else if (msg.isFile)
                    _FileBubble(fileName: msg.fileName, fileSize: msg.fileSize, fileUrl: msg.fileUrl, isMe: msg.isMe, isDark: isDark)
                  else
                    _TextBubble(text: msg.text, isMe: msg.isMe, isDark: isDark),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatTime(msg.time), style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                      if (msg.isMe && !msg.recalled)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(Icons.done_all, size: 12,
                            color: msg.read ? const Color(0xFF1AA4EC) : const Color(0xFFAAAAAA)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (msg.isMe) const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildRecalledBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E254A) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        msg.isMe ? '你撤回了一条消息' : '${msg.sender ?? "对方"}撤回了一条消息',
        style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA), fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildReplyQuote() {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(msg.isMe ? 14 : 6),
          topRight: Radius.circular(msg.isMe ? 6 : 14),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        border: Border(left: BorderSide(color: const Color(0xFF1AA4EC), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            msg.replySender ?? '消息',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1AA4EC)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            msg.replyText ?? '',
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isDark;
  const _TextBubble({required this.text, required this.isMe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth * 0.65;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF1AA4EC) : (isDark ? const Color(0xFF1E254A) : Colors.white),
            borderRadius: isMe
                ? const BorderRadius.only(
                    topLeft: Radius.circular(14), topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14), bottomRight: Radius.circular(4))
                : const BorderRadius.only(
                    topLeft: Radius.circular(14), topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(4), bottomRight: Radius.circular(14)),
            boxShadow: isMe ? [] : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          constraints: BoxConstraints(maxWidth: maxW < 200 ? 200 : maxW),
          child: Text(
            text,
            style: TextStyle(fontSize: 14, height: 1.45,
              color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF202124))),
          ),
        );
      },
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String path;
  final bool isMe;
  final bool isDark;
  const _ImageBubble({required this.path, required this.isMe, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ImagePreviewPage(imageUrl: path)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CachedNetworkImage(
            imageUrl: path.startsWith('http') ? path : '${ApiService.baseUrl}/uploads/${path.replaceAll('/uploads/', '')}',
            width: 180, height: 180,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 180, height: 180,
              color: isDark ? const Color(0xFF1E254A) : const Color(0xFFF2F5F9),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 180, height: 180,
              color: isDark ? const Color(0xFF1E254A) : const Color(0xFFF2F5F9),
              child: const Center(child: Icon(Icons.broken_image, size: 32, color: Color(0xFFAAAAAA))),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final _Msg msg;
  final VoidCallback onCancel;
  final bool isDark;
  const _ReplyBar({required this.msg, required this.onCancel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E254A) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF252B44) : const Color(0xFFE9E9E9))),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: const Color(0xFF1AA4EC)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(msg.isMe ? '我' : (msg.sender ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1AA4EC))),
                Text(msg.text, style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
