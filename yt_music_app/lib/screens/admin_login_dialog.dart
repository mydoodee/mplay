import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import '../l10n/app_localizations.dart';

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

  @override
  void initState() {
    super.initState();
  }

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
          builder: (context) =>
              AdminDashboardScreen(username: user, password: pass),
        ),
      );
    } else {
      setState(() {
        _errorMsg = AppLocalizations.of(context)!.adminLoginInvalid;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        AppLocalizations.of(context)!.adminLoginTitle,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.usernameLabel,
              labelStyle: const TextStyle(color: Color(0xFF777777)),
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
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.passwordLabel,
              labelStyle: const TextStyle(color: Color(0xFF777777)),
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
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.of(context)!.cancel,
            style: const TextStyle(color: Color(0xFF777777)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFF15A24),
                    strokeWidth: 2,
                  ),
                )
              : Text(AppLocalizations.of(context)!.adminLogin),
        ),
      ],
    );
  }
}
