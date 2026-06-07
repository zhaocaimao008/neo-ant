import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (username.isEmpty || pwd.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      String deviceId = 'unknown';
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isWindows) {
          deviceId = 'windows-${const Uuid().v4()}';
        }
      } catch (_) {}

      final result = await ApiService().login(username, pwd, deviceId: deviceId);
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(userId: userId)),
        );
      } else {
        setState(() {
          _error = result['error']?.toString() ?? result['message']?.toString() ?? '登录失败';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1AA4EC), Color(0xFF168CCA)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text('A', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Ant Messenger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF202124))),
                const SizedBox(height: 6),
                Text('登录到 Ant Messenger', style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                const SizedBox(height: 36),

                // Username
                TextField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    hintText: '输入账号',
                    prefixIcon: Icon(Icons.person_outlined, size: 20, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Password
                TextField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: '输入密码',
                    prefixIcon: Icon(Icons.lock_outlined, size: 20, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                  ),

                // Login button
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1AA4EC),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1AA4EC).withAlpha(150),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('登录', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 16),
                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('还没有账号？',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF8E95A8) : const Color(0xFFAAAAAA))),
                    GestureDetector(
                      onTap: _loading ? null : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: Text('立即注册',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(0xFF1AA4EC))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
