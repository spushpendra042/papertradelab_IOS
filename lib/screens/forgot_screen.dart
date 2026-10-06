import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../main.dart';
import 'login_screen.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        final email = _email.text.trim();
        if (!email.contains('@')) throw ApiException('Enter a valid email address.');
        await context.read<Api>().forgotPassword(email);
        if (mounted) setState(() => _sent = true);
      });

  Future<void> _reset() => _run(() async {
        if (_password.text.length < 8) throw ApiException('Password must be at least 8 characters.');
        await context.read<Api>().resetPassword(_email.text.trim(), _otp.text.trim(), _password.text);
        if (!mounted) return;
        Navigator.of(context).pop();
        showBanner('Password changed', 'Log in with your new password.');
      });

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Reset password',
      subtitle: _sent
          ? 'If that email is registered, a code is on its way.'
          : 'We will email you a code to set a new password.',
      children: [
        TextField(
          controller: _email,
          enabled: !_sent,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        if (_sent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code from email', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password (8+ characters)'),
          ),
        ],
        ErrorText(_error),
        BusyButton(
          busy: _busy,
          label: _sent ? 'Set new password' : 'Send code',
          onPressed: _sent ? _reset : _send,
        ),
      ],
    );
  }
}
