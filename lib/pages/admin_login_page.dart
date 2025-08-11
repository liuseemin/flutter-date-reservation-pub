import 'package:flutter/material.dart';

/// 如果你真的想看的話就看吧
const _adminPassword = 'password';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _login() {
    if (_pwCtrl.text == _adminPassword) {
      Navigator.pushReplacementNamed(
        context,
        '/admin',
        arguments: _pwCtrl.text,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密碼錯誤，請再試一次')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者登入')),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _pwCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '管理密碼',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _login, child: const Text('登入')),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('問題回報'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Developer'), Text('Developer info')],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, '確定'),
                child: const Text('確定'),
              ),
            ],
          ),
        ),
        tooltip: '問題回報',
        child: const Icon(Icons.question_mark),
      ),
    );
  }
}
