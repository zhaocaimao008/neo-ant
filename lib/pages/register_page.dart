import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _inviteCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final inviteCode = _inviteCtrl.text.trim().toUpperCase();
    final pwd = _pwdCtrl.text;
    final confirmPwd = _confirmPwdCtrl.text;

    // Validation
    if (name.isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }
    if (username.isEmpty && phone.isEmpty) {
      setState(() => _error = '请输入账号或手机号');
      return;
    }
    if (inviteCode.isEmpty) {
      setState(() => _error = '请输入邀请码');
      return;
    }
    if (inviteCode.length < 4) {
      setState(() => _error = '邀请码格式不正确');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = '密码太短（至少6位）');
      return;
    }
    if (pwd != confirmPwd) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final result = await ApiService().register(username, name, pwd, inviteCode: inviteCode, phone: phone);
      if (!mounted) return;
      if (result['ok'] == true) {
        final user = result['user'] as Map;
        final userId = user['id'] as String;
        final token = result['token'] as String? ?? '';
        // Persist login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        const storage = FlutterSecureStorage();
        await storage.write(key: 'authToken', value: token);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomePage(userId: userId)),
          (route) => false,
        );
      } else {
        setState(() {
          _error = result['error']?.toString() ?? result['message']?.toString() ?? '注册失败';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '网络错误，请检查连接');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xE0111735) : const Color(0xE0FFFFFF),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? const Color(0xFF5A6180) : const Color(0xFF5E5E5E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('注册账号',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFF0F2F5) : const Color(0xFF202124))),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // Name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: '输入昵称',
                    prefixIcon: Icon(Icons.person_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Username
                TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    hintText: '输入账号',
                    prefixIcon: Icon(Icons.person_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Phone (optional)
                TextField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(
                    hintText: '手机号（选填）',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                  ),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                // Invite Code
                TextField(
                  controller: _inviteCtrl,
                  decoration: InputDecoration(
                    hintText: '邀请码',
                    prefixIcon: Icon(Icons.vpn_key_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                  ),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 14),

                // Password
                TextField(
                  controller: _pwdCtrl,
                  obscureText: _obscurePwd,
                  decoration: InputDecoration(
                    hintText: '输入密码',
                    prefixIcon: Icon(Icons.lock_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Confirm password
                TextField(
                  controller: _confirmPwdCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: '确认密码',
                    prefixIcon: Icon(Icons.lock_outlined, size: 20,
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                  ),

                // Register button
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1AA4EC),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1AA4EC).withAlpha(150),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('注册', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('已有账号？',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text('返回登录',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1AA4EC))),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
