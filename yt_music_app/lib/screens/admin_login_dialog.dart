import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  void _login() {
    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });

    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    // Verify credentials locally first
    if (user == 'admingrow' && pass == 'Kub@987*') {
      Navigator.pop(context); // Close dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminDashboardScreen(
            username: user,
            password: pass,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMsg = 'รหัสผ่านหรือชื่อผู้ใช้ไม่ถูกต้อง';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'mPlay System Admin',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(color: Color(0xFF777777)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF444444)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF15A24)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Color(0xFF777777)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF444444)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF15A24)),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMsg!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF777777))),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('เข้าสู่ระบบ'),
        ),
      ],
    );
  }
}
