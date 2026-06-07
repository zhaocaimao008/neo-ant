import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Admin2faPage extends StatefulWidget {
  const Admin2faPage({super.key});
  @override
  State<Admin2faPage> createState() => _Admin2faPageState();
}

class _Admin2faPageState extends State<Admin2faPage> {
  bool _enabled = false;
  String _secret = '';
  String _qrUrl = '';
  final _codeController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await ApiService().adminApi('/api/admin/2fa/status');
      setState(() {
        _enabled = data['enabled'] == true;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _setup() async {
    try {
      final data = await ApiService().adminApi('/api/admin/2fa/setup', method: 'POST');
      setState(() {
        _secret = data['secret'] ?? '';
        _qrUrl = data['qrCode'] ?? '';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('设置失败: $e')));
    }
  }

  Future<void> _verify() async {
    try {
      await ApiService().adminApi('/api/admin/2fa/verify', method: 'POST', body: {'token': _codeController.text});
      setState(() => _enabled = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('双重验证已启用')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('验证失败: $e')));
    }
  }

  Future<void> _disable() async {
    try {
      await ApiService().adminApi('/api/admin/2fa/disable', method: 'POST');
      setState(() { _enabled = false; _secret = ''; _qrUrl = ''; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('双重验证已关闭')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('关闭失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('双重验证')),
      body: _loading ? const Center(child: CircularProgressIndicator())
      : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('状态: ${_enabled ? "已启用" : "未启用"}', style: TextStyle(fontSize: 16, color: _enabled ? Colors.green : Colors.red)),
            const SizedBox(height: 20),
            if (_enabled)
              ElevatedButton(onPressed: _disable, child: const Text('关闭双重验证'))
            else if (_secret.isEmpty)
              ElevatedButton(onPressed: _setup, child: const Text('开启双重验证'))
            else ...[
              const Text('请使用 Google Authenticator 扫描以下二维码或输入密钥：'),
              if (_qrUrl.isNotEmpty) Image.network(_qrUrl, height: 200),
              if (_secret.isNotEmpty) SelectableText('密钥: $_secret'),
              const SizedBox(height: 12),
              TextField(controller: _codeController, decoration: const InputDecoration(labelText: '输入验证码', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _verify, child: const Text('验证')),
            ],
          ],
        ),
      ),
    );
  }
}
