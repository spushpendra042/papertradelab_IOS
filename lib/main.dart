import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'config.dart';
import 'logo.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_state.dart';
import 'state/alerts_state.dart';
import 'state/live_state.dart';
import 'state/market_state.dart';
import 'state/portfolio_state.dart';
import 'theme.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void showBanner(String title, String body) {
  messengerKey.currentState?.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: C.panelHi,
    duration: const Duration(seconds: 6),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        if (body.isNotEmpty) Text(body, style: const TextStyle(color: C.muted)),
      ],
    ),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final api = await Api.create();
  runApp(MultiProvider(
    providers: [
      Provider<Api>.value(value: api),
      ChangeNotifierProvider<AuthState>(create: (_) => AuthState(api)..bootstrap()),
      ChangeNotifierProvider<LiveState>(create: (_) => LiveState(api)),
      ChangeNotifierProvider<PortfolioState>(create: (_) => PortfolioState(api)),
      ChangeNotifierProvider<MarketState>(create: (_) => MarketState(api)),
      ChangeNotifierProvider<AlertsState>(create: (_) => AlertsState()),
    ],
    child: const PtlApp(),
  ));
}

class PtlApp extends StatelessWidget {
  const PtlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    Widget home;
    switch (auth.status) {
      case AuthStatus.unknown:
        home = _Splash(error: auth.bootError, onRetry: auth.bootstrap);
        break;
      case AuthStatus.signedOut:
        home = const LoginScreen();
        break;
      case AuthStatus.signedIn:
        home = const HomeShell();
        break;
    }
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: messengerKey,
      home: home,
    );
  }
}

class _Splash extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _Splash({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 96),
              const SizedBox(height: 16),
              const Text(AppConfig.appName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
              const SizedBox(height: 28),
              if (error == null)
                const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
              else ...[
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
