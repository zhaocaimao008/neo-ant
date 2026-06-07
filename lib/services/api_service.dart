import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ApiService {
  // Production server URL — set via --dart-define=SERVER_URL=https://dipsin.com
  // When empty, uses relative URLs (works for web served from same domain)
  static const String _serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: 'https://dipsin.com');
  static const String baseUrl = _serverUrl;
  static bool get _isProduction => _serverUrl.isNotEmpty;
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String? _token;
  String? _currentUserId;
  String? _currentUserName;
  String get currentUserId => _currentUserId ?? '';
  String get currentUserName => _currentUserName ?? '';

  void setToken(String? token) {
    _token = token;
    // Update Dio default headers
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  String? _wsUserId;

  // ─── Stream-based event system ──────────────────────────────
  final StreamController<Map> _messageController = StreamController<Map>.broadcast();
  final StreamController<Map> _callController = StreamController<Map>.broadcast();
  final StreamController<Map> _typingController = StreamController<Map>.broadcast();
  final StreamController<Map> _contactController = StreamController<Map>.broadcast();

  Stream<Map> get messageStream => _messageController.stream;
  Stream<Map> get callStream => _callController.stream;
  Stream<Map> get typingStream => _typingController.stream;
  Stream<Map> get contactStream => _contactController.stream;

  // ─── Auth ────────────────────────────────────────────────────
  Future<Map> login(String username, String password, {String? deviceId}) async {
    final r = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
    });
    if (r.data['ok'] == true) {
      _currentUserName = r.data['user']?['name'] ?? r.data['user']?['username'] ?? '';
      final token = r.data['token'] as String?;
      if (token != null) setToken(token);
    }
    return r.data;
  }

  Future<Map> register(String username, String name, String password, {String? inviteCode, String? phone}) async {
    final r = await _dio.post('/api/auth/register', data: {
      'username': username,
      'name': name,
      'password': password,
      if (inviteCode != null) 'inviteCode': inviteCode,
      if (phone != null) 'phone': phone,
    });
    if (r.data['ok'] == true) {
      _currentUserName = r.data['user']?['name'] ?? r.data['user']?['username'] ?? '';
      final token = r.data['token'] as String?;
      if (token != null) setToken(token);
    }
    return r.data;
  }

  // ─── User ────────────────────────────────────────────────────
  Future<Map> getUser(String id) async {
    final r = await _dio.get('/api/users/$id');
    return r.data;
  }

  Future<void> updateProfile(String userId, {String? name, String? avatar, String? phone}) async {
    await _dio.post('/api/profile/update', data: {'userId': userId, 'name': name, 'avatar': avatar, 'phone': phone});
  }

  // ─── Conversations ──────────────────────────────────────────
  Future<List> getConversations(String userId) async {
    final r = await _dio.get('/api/conversations/$userId');
    return r.data;
  }

  // ─── Messages ───────────────────────────────────────────────
  Future<List> getMessages(String conversationId, {String? before, int limit = 50}) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;
    final r = await _dio.get('/api/messages/$conversationId', queryParameters: params);
    return r.data;
  }

  Future<Map> sendMessage(String conversationId, String senderId, String text,
      {String type = 'text', String? filePath}) async {
    final form = FormData.fromMap({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'text': text,
      'type': type,
      if (filePath != null) 'file': await MultipartFile.fromFile(filePath),
    });
    final r = await _dio.post('/api/messages', data: form);
    return r.data;
  }

  // ─── Favorites ──────────────────────────────────────────────
  Future<Map> getFavorites(String userId) async {
    final r = await _dio.get('/api/favorites/$userId');
    return r.data;
  }

  Future<void> addFavorite(String userId, String messageId, String conversationId, String text, String senderName) async {
    await _dio.post('/api/favorites/add', data: {
      'userId': userId,
      'messageId': messageId,
      'conversationId': conversationId,
      'text': text,
      'senderName': senderName,
    });
  }

  Future<void> removeFavorite(String id) async {
    await _dio.post('/api/favorites/remove', data: {'id': id});
  }

  // ─── Drafts ─────────────────────────────────────────────────
  Future<Map> getDraft(String userId, String conversationId) async {
    final r = await _dio.get('/api/drafts/$userId/$conversationId');
    return r.data;
  }

  Future<void> saveDraft(String userId, String conversationId, String content) async {
    await _dio.post('/api/drafts/save', data: {
      'userId': userId,
      'conversationId': conversationId,
      'content': content,
    });
  }

  // ─── Forward ────────────────────────────────────────────────
  Future<void> forwardMessage(String senderId, String targetConversationId, String text, String type, String fileUrl) async {
    await _dio.post('/api/messages/forward', data: {
      'senderId': senderId,
      'targetConversationId': targetConversationId,
      'originalText': text,
      'originalType': type,
      'originalFileUrl': fileUrl,
    });
  }

  // ─── Delete Message ───────────────────────────────────────
  Future<void> deleteMessage(String messageId, String conversationId) async {
    await _dio.post('/api/messages/delete', data: {
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  // ─── Groups ─────────────────────────────────────────────────
  Future<List> getGroupMembers(String groupId) async {
    final r = await _dio.get('/api/groups/$groupId/members');
    return r.data;
  }

  Future<void> inviteGroupMember(String groupId, String userId, String memberUsername) async {
    await _dio.post('/api/groups/$groupId/invite', data: {
      'userId': userId,
      'memberUsername': memberUsername,
    });
  }

  Future<void> removeGroupMember(String groupId, String memberId) async {
    await _dio.post('/api/groups/$groupId/remove', data: {'memberId': memberId});
  }

  Future<void> updateGroupInfo(String groupId, {String? name, String? avatar}) async {
    await _dio.post('/api/groups/$groupId/update', data: {
      if (name != null) 'name': name,
      if (avatar != null) 'avatar': avatar,
    });
  }

  // ─── Settings ───────────────────────────────────────────────
  Future<Map> getSettings(String userId) async {
    final r = await _dio.get('/api/settings/$userId');
    return r.data;
  }

  Future<void> updateSettings(String userId, Map updates) async {
    await _dio.post('/api/settings/update', data: {
      'userId': userId,
      ...updates,
    });
  }

  // ─── Contacts ───────────────────────────────────────────────
  Future<List> getContacts(String userId) async {
    final r = await _dio.get('/api/contacts/$userId');
    return r.data;
  }

  Future<void> addContact(String userId, String contactUsername, {String remark = '', String? contactPhone}) async {
    await _dio.post('/api/contacts/add', data: {
      'userId': userId,
      'contactUsername': contactUsername,
      'remark': remark,
      if (contactPhone != null) 'contactPhone': contactPhone,
    });
  }

  Future<void> removeContact(String userId, String contactName) async {
    await _dio.post('/api/contacts/remove', data: {
      'userId': userId,
      'contactName': contactName,
    });
  }

  // ─── Search ─────────────────────────────────────────────────
  Future<List> searchUsers(String q) async {
    final r = await _dio.get('/api/search/users', queryParameters: {'q': q});
    return r.data;
  }

  Future<List> searchMessages(String userId, String q) async {
    final r = await _dio.get('/api/search/messages/$userId', queryParameters: {'q': q});
    return r.data;
  }

  // ─── Invite Codes ──────────────────────────────────────────
  Future<Map> generateInviteCodes(String userId, {int count = 1}) async {
    final r = await _dio.post('/api/invite/generate', data: {'userId': userId, 'count': count});
    return r.data;
  }

  Future<List> listInviteCodes(String userId) async {
    final r = await _dio.get('/api/invite/list', queryParameters: {'userId': userId});
    return r.data;
  }

  // ─── Admin ──────────────────────────────────────────────────
  Future<dynamic> adminApi(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    final r = await _dio.request(path,
        data: body,
        options: Options(method: method));
    return r.data;
  }

  Future<Map> adminGetStats() async {
    final r = await _dio.get('/api/admin/stats');
    return r.data;
  }

  Future<Map> adminGetUsers({int page = 1, int limit = 50}) async {
    final r = await _dio.get('/api/admin/users', queryParameters: {'page': page, 'limit': limit});
    return r.data;
  }

  Future<void> adminBanUser(String userId, {bool ban = true}) async {
    await _dio.post('/api/admin/users/ban', data: {'userId': userId, 'ban': ban});
  }

  Future<Map> adminGetInviteCodes({int page = 1, int limit = 50}) async {
    final r = await _dio.get('/api/admin/invite-codes', queryParameters: {'page': page, 'limit': limit});
    return r.data;
  }

  Future<void> adminGenerateInviteCodes({int count = 1, int maxUses = 1}) async {
    await _dio.post('/api/admin/invite-codes/generate', data: {'count': count, 'maxUses': maxUses});
  }

  Future<void> adminDeleteInviteCode(String code) async {
    await _dio.post('/api/admin/invite-codes/delete', data: {'code': code});
  }

  // ─── 2FA ────────────────────────────────────────────────────
  Future<Map> verify2fa(String tempToken, String code) async {
    final r = await _dio.post('/api/auth/2fa/verify', data: {
      'tempToken': tempToken,
      'code': code,
    });
    return r.data;
  }

  Future<Map> get2faStatus(String userId) async {
    final r = await _dio.get('/api/2fa/status/$userId');
    return r.data;
  }

  Future<Map> setup2fa(String userId) async {
    final r = await _dio.post('/api/2fa/setup', data: {'userId': userId});
    return r.data;
  }

  Future<Map> verify2faSetup(String userId, String code) async {
    final r = await _dio.post('/api/2fa/verify-setup', data: {'userId': userId, 'code': code});
    return r.data;
  }

  Future<void> disable2fa(String userId, String code) async {
    await _dio.post('/api/2fa/disable', data: {'userId': userId, 'code': code});
  }

  Future<Map> banDevice(String userId, String deviceId) async {
    final r = await _dio.post('/api/admin/devices/ban', data: {'userId': userId, 'deviceId': deviceId});
    return r.data;
  }

  Future<Map> banIp(String ip) async {
    final r = await _dio.post('/api/admin/ip/ban', data: {'ip': ip});
    return r.data;
  }

  // ─── Friend Requests ─────────────────────────────────────────
  Future<List> getFriendRequests(String userId) async {
    final r = await _dio.get('/api/friend-requests/$userId');
    return r.data;
  }

  Future<void> respondToFriendRequest(String requestId, String action) async {
    await _dio.post('/api/friend-requests/respond', data: {
      'requestId': requestId,
      'action': action, // 'accepted' or 'rejected'
    });
  }

  // ─── Upload ─────────────────────────────────────────────────
  Future<Map> uploadFile(String filePath) async {
    final form = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    final r = await _dio.post('/api/upload', data: form);
    return r.data;
  }

  // ─── Typing Indicator ──────────────────────────────────────
  void sendTyping(String conversationId, String senderId) {
    sendWsMessage({
      'type': 'typing',
      'conversation_id': conversationId,
      'sender_id': senderId,
    });
  }

  // ─── WebSocket ──────────────────────────────────────────────
  final List<Map> _pendingMessages = [];
  Timer? _pingTimer;

  void connectWs(String userId) {
    _currentUserId = userId;
    _wsUserId = userId;
    _wsChannel?.sink.close();
    _wsSubscription?.cancel();
    _pingTimer?.cancel();
    try {
      final scheme;
      String host;
      int port;
      if (_isProduction) {
        final uri = Uri.parse(_serverUrl);
        scheme = uri.scheme == 'https' ? 'wss' : 'ws';
        host = uri.host;
        port = uri.port;
      } else {
        scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
        host = Uri.base.host;
        port = Uri.base.port;
      }
      String wsUrl = '$scheme://$host:$port/ws?userId=$userId';
      if (_token != null) wsUrl += '&token=$_token';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSubscription = _wsChannel!.stream.listen((data) {
        final parsed = jsonDecode(data as String) as Map;
        final type = parsed['type'] as String? ?? '';
        // Handle pong responses
        if (type == 'pong') return;
        if (type == 'typing') {
          _typingController.add(parsed);
        } else if (type == 'call:offer' || type == 'call:answer' ||
            type == 'call:ice' || type == 'call:end' ||
            type == 'call:busy') {
          _callController.add(parsed);
        } else if (type == 'contact:added') {
          _contactController.add(parsed);
        } else if (type == 'message:deleted') {
          _messageController.add(parsed);
        } else if (parsed.containsKey('id') && parsed.containsKey('conversation_id')) {
          // Incoming messages from server have id+conversation_id but type='text'/'image'/etc
          _messageController.add(parsed);
        }
      }, onError: (e) {
        _reconnect(userId);
      }, onDone: () {
        _reconnect(userId);
      });
      // Start ping timer (every 30 seconds)
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        sendWsMessage({'type': 'ping'});
      });
      // Flush any pending messages
      _flushPendingMessages();
    } catch (_) {}
  }

  bool _reconnecting = false;
  void _reconnect(String userId) {
    if (_reconnecting) return;
    _reconnecting = true;
    Future.delayed(const Duration(seconds: 3), () {
      _reconnecting = false;
      connectWs(userId);
    });
  }

  void sendWsMessage(Map msg) {
    if (_wsChannel != null && _wsChannel!.sink != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(msg));
      } catch (e) {
        print('WS send error: $e');
        _pendingMessages.add(msg);
      }
    } else {
      _pendingMessages.add(msg);
    }
  }

  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty) return;
    final queue = List<Map>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final msg in queue) {
      try {
        _wsChannel?.sink.add(jsonEncode(msg));
      } catch (e) {
        print('WS flush error: $e');
        _pendingMessages.add(msg);
      }
    }
  }

  void disconnectWs() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _currentUserId = null;
    _wsUserId = null;
  }

  void dispose() {
    disconnectWs();
    _messageController.close();
    _callController.close();
    _typingController.close();
    _contactController.close();
  }

  void logout() {
    setToken(null);
    disconnectWs();
  }
}
