import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum CallState { calling, ringing, connected, ended, rejected, missed }

class CallPage extends StatefulWidget {
  final String userId;
  final String targetUserId;
  final String targetName;
  final bool isVideo;
  final bool isIncoming;
  final Map? incomingOffer;

  const CallPage({
    super.key,
    required this.userId,
    required this.targetUserId,
    required this.targetName,
    this.isVideo = false,
    this.isIncoming = false,
    this.incomingOffer,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with WidgetsBindingObserver {
  CallState _state = CallState.calling;
  bool _micEnabled = true;
  int _callSeconds = 0;
  Timer? _timer;
  StreamSubscription<Map>? _callSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSub = ApiService().callStream.listen(_handleCallMessage);
    _doCall();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSub?.cancel();
    _cleanup();
    super.dispose();
  }

  void _cleanup() {
    _timer?.cancel();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  String get _formattedTime {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _doCall() async {
    try {
      if (widget.isIncoming && widget.incomingOffer != null) {
        setState(() => _state = CallState.ringing);
      } else {
        setState(() => _state = CallState.calling);
        // Send offer via WS
        ApiService().sendWsMessage({
          'type': 'call:offer',
          'targetUserId': widget.targetUserId,
          'sdp': {'sdp': 'pending', 'type': 'offer'},
          'callType': widget.isVideo ? 'video' : 'audio',
          'fromName': ApiService().currentUserName,
        });
      }
    } catch (_) {
      if (mounted) _endCall();
    }
  }

  void _handleCallMessage(Map msg) {
    final type = msg['type'] as String?;
    if (type == null) return;
    if (type == 'call:answer' && _state == CallState.calling) {
      if (mounted) {
        setState(() => _state = CallState.connected);
        _startTimer();
      }
    } else if (type == 'call:end') {
      if (mounted) setState(() => _state = CallState.ended);
    } else if (type == 'call:busy') {
      if (mounted) setState(() => _state = CallState.rejected);
    }
  }

  Future<void> _answerCall() async {
    ApiService().sendWsMessage({
      'type': 'call:answer',
      'targetUserId': widget.targetUserId,
      'sdp': {'sdp': 'accepted', 'type': 'answer'},
    });
    if (mounted) {
      setState(() => _state = CallState.connected);
      _startTimer();
    }
  }

  void _rejectCall() {
    ApiService().sendWsMessage({'type': 'call:end', 'targetUserId': widget.targetUserId});
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _endCall() {
    ApiService().sendWsMessage({'type': 'call:end', 'targetUserId': widget.targetUserId});
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() => _micEnabled = !_micEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFF1AA4EC),
                        child: Text(
                          widget.targetName.isNotEmpty ? widget.targetName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.targetName,
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(_stateMessage,
                        style: TextStyle(fontSize: 15,
                          color: _state == CallState.connected ? const Color(0xFF52C41A) : Colors.white70)),
                      if (_state == CallState.calling) ...[
                        const SizedBox(height: 24),
                        const SizedBox(width: 32, height: 32,
                          child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_state == CallState.connected)
              Positioned(
                top: 16, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: const Color(0xFF52C41A)),
                        const SizedBox(width: 8),
                        Text(_formattedTime,
                          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_state == CallState.ringing)
              Positioned(
                bottom: 140, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallBtn(icon: Icons.call, color: const Color(0xFF34C759), size: 68, onTap: _answerCall),
                    const SizedBox(width: 80),
                    _CallBtn(icon: Icons.call_end, color: const Color(0xFFFF3B30), size: 68, onTap: _rejectCall),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildControls(),
    );
  }

  String get _stateMessage {
    switch (_state) {
      case CallState.calling: return '正在呼叫...';
      case CallState.ringing: return '来电...';
      case CallState.connected: return '通话中';
      case CallState.ended: return '通话已结束';
      case CallState.rejected: return '对方忙线';
      case CallState.missed: return '未接来电';
    }
  }

  Widget _buildControls() {
    if (_state == CallState.ended || _state == CallState.rejected) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              label: const Text('关闭', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
          ),
        ),
      );
    }
    if (_state != CallState.connected) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFF141414),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallBtn(icon: Icons.mic, active: _micEnabled, size: 56, onTap: _toggleMute),
          const SizedBox(width: 28),
          _CallBtn(icon: Icons.call_end, color: const Color(0xFFFF3B30), size: 56, onTap: _endCall),
        ],
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? color;
  final double size;
  final VoidCallback? onTap;

  const _CallBtn({
    required this.icon,
    this.active = true,
    this.color,
    this.size = 52,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? (active ? Colors.white24 : Colors.white12);
    final iconColor = color ?? (active ? Colors.white : Colors.white38);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.42),
      ),
    );
  }
}
