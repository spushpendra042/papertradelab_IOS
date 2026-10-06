import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Step 1: email + password → OTP is emailed.  Step 2: enter OTP → account created + logged in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _otpStep = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Api>().register(email, _password.text);
      if (!mounted) return;
      setState(() => _otpStep = true);
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length < 4) {
      setState(() => _error = 'Enter the code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().completeRegistration(_otp.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_otpStep) {
      return AuthScaffold(
        showBack: true,
        title: 'Check your email',
        subtitle: 'We sent a verification code to\n${_email.text.trim()}',
        children: [
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onSubmitted: (_) => _verify(),
          ),
          ErrorText(_error),
          BusyButton(busy: _busy, label: 'Verify and continue', onPressed: _verify),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_cooldown > 0 || _busy) ? null : _sendOtp,
            child: Text(_cooldown > 0 ? 'Resend code in ${_cooldown}s' : 'Resend code'),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() { _otpStep = false; _error = null; }),
            child: const Text('Use a different email'),
          ),
        ],
      );
    }
    return AuthScaffold(
      showBack: true,
      title: 'Create account',
      subtitle: 'Free trial included. No card needed.',
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _hide,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _sendOtp(),
          decoration: InputDecoration(
            labelText: 'Password (8+ characters)',
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        ErrorText(_error),
        BusyButton(busy: _busy, label: 'Send verification code', onPressed: _sendOtp),
        const SizedBox(height: 12),
        const Text('By continuing you agree that signals are educational and not investment advice.',
            textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
      ],
    );
  }
}
