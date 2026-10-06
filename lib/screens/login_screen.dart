import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../logo.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'forgot_screen.dart';
import 'register_screen.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;
  const AuthScaffold(
      {super.key, required this.title, required this.subtitle, required this.children, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    const Center(child: AppLogo(size: 84)),
                    const SizedBox(height: 12),
                  ],
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.text)),
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  final String? message;
  const ErrorText(this.message, {super.key});
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: C.red)),
    );
  }
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onPressed;
  const BusyButton({super.key, required this.busy, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.onGold))
          : Text(label),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(email, _password.text);
      // Success: the root widget swaps to the home screen by itself.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: AppConfig.appName,
      subtitle: 'Live strategy signals with a fully open track record',
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
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotScreen())),
            child: const Text('Forgot password?'),
          ),
        ),
        ErrorText(_error),
        BusyButton(busy: _busy, label: 'Log in', onPressed: _submit),
        const SizedBox(height: 14),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: const Text('Create a free account'),
        ),
        const SizedBox(height: 10),
        const Text('You only need to log in once on this phone.',
            textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
      ],
    );
  }
}
