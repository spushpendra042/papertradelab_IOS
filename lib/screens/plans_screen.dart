import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../main.dart';
import '../state/auth_state.dart';
import '../state/live_state.dart';
import '../support.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Plan picker + Cashfree checkout (STORE=direct builds only).
///
/// Checkout opens in a browser tab on top of the app, using a small page served
/// by our own backend (/m/pay) that runs the same Cashfree checkout the website
/// uses. While it is open — and when the user comes back — the app keeps asking
/// the server (/verify-payment) whether the order is paid. The server decides.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  final _phone = TextEditingController();
  List<Map<String, dynamic>> _plans = [];
  String? _selected;
  String? _error;
  bool _loading = true;
  bool _starting = false;

  // Non-null while we are waiting for a payment to complete.
  String? _orderId;
  String? _sessionId;
  Timer? _poll;
  bool _checking = false;
  int _checks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _phone.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the payment tab → check straight away.
    if (state == AppLifecycleState.resumed && _orderId != null) _check();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().plans();
      if (!mounted) return;
      setState(() {
        _plans = asList(r['plans']).map(asMap).toList();
        _selected = _plans.isNotEmpty ? asS(_plans.last['id']) : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pay() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 10) {
      setState(() => _error = 'Enter your 10-digit mobile number (needed by the payment gateway).');
      return;
    }
    final plan = _selected;
    if (plan == null) return;
    setState(() {
      _error = null;
      _starting = true;
    });
    try {
      final order = await context.read<Api>().createOrder(plan, phone);
      final orderId = asS(order['order_id']);
      final sessionId = asS(order['payment_session_id']);
      if (orderId.isEmpty || sessionId.isEmpty) {
        throw ApiException('Could not start the payment. Please try again.');
      }
      if (!mounted) return;
      setState(() {
        _orderId = orderId;
        _sessionId = sessionId;
        _checks = 0;
      });
      await _openCheckout();
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _openCheckout() async {
    final sid = _sessionId;
    if (sid == null) return;
    final url = Uri.parse('${AppConfig.baseUrl}/m/pay').replace(queryParameters: {'sid': sid});
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      try {
        opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      setState(() => _error = 'Could not open the payment page. Install or enable a web browser (Chrome) and try again.');
    }
  }

  Future<void> _check() async {
    final orderId = _orderId;
    if (orderId == null || _checking) return;
    _checking = true;
    try {
      final r = await context.read<Api>().verifyPayment(orderId);
      final status = asS(r['status']);
      if (!mounted) return;
      if (status == 'success') {
        _poll?.cancel();
        await context.read<AuthState>().refresh();
        if (!mounted) return;
        context.read<LiveState>().refreshNow();
        Navigator.of(context).pop();
        showBanner('Subscription active 🎉', 'Live signals are unlocked.');
        return;
      }
      if (status == 'failed') {
        _stopWaiting('Payment was not completed. No plan was activated — you can try again.');
        return;
      }
      _checks++;
      if (_checks > 150) {
        // ~10 minutes
        _stopWaiting('We stopped waiting for this payment. If money was deducted, your plan activates '
            'automatically within a few minutes — pull down on the Account tab to refresh.');
      }
    } on ApiException catch (_) {
      // Network blip while the payment tab is open: just try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  void _stopWaiting(String? message) {
    _poll?.cancel();
    if (!mounted) return;
    setState(() {
      _orderId = null;
      _sessionId = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _orderId != null;
    final busy = _starting || waiting;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a plan')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const _Benefit(Icons.bolt, 'Every live SELL / BUY signal the moment it fires'),
                      const _Benefit(Icons.lock, 'Live stoploss, target and risk-free updates'),
                      const _Benefit(Icons.notifications_active, 'Instant notifications, even with the app closed'),
                      const _Benefit(Icons.checklist, 'Full condition checklist — see signals forming'),
                      const SizedBox(height: 14),
                      for (final p in _plans) _planTile(p, busy),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phone,
                        enabled: !busy,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                            labelText: 'Mobile number', prefixText: '+91 ', counterText: ''),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: const TextStyle(color: C.red)),
                        ),
                      const SizedBox(height: 16),
                      if (!waiting)
                        FilledButton(
                          onPressed: (busy || _selected == null) ? null : _pay,
                          child: _starting
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: C.onGold))
                              : const Text('Pay securely'),
                        )
                      else
                        Panel(
                          borderColor: C.accent.withAlpha(140),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: const [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Waiting for your payment…',
                                    style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            const Text(
                                'Finish the payment on the page that opened. This screen updates by itself '
                                'as soon as the payment is confirmed.',
                                style: TextStyle(color: C.muted, fontSize: 13)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: _openCheckout, child: const Text('Open payment page again')),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                              onPressed: _check,
                              child: const Text('I have paid — check now'),
                            ),
                            TextButton(onPressed: () => _stopWaiting(null), child: const Text('Cancel')),
                          ]),
                        ),
                      const SizedBox(height: 10),
                      const Text('UPI, cards and net-banking via Cashfree. Your plan extends from your current expiry date.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
                      TextButton(
                        onPressed: () => contactSupport(
                            accountEmail: context.read<AuthState>().email,
                            topic: _orderId == null ? 'Payment help' : 'Payment help (order $_orderId)'),
                        child: const Text('Paid but not activated? Email ${AppConfig.supportEmail}'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _planTile(Map<String, dynamic> p, bool busy) {
    final id = asS(p['id']);
    final selected = id == _selected;
    final amount = asD(p['amount']) ?? 0;
    final days = asI(p['days'], 30);
    final perMonth = amount / (days / 30);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : () => setState(() => _selected = id),
        child: Panel(
          borderColor: selected ? C.accent : C.border,
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? C.accent : C.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(asS(p['label']), style: const TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('$days days · about ${fmtInr(perMonth)}/month', style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
            ),
            Text(fmtInr(amount), style: const TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Benefit(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: C.green),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: C.text, fontSize: 13))),
      ]),
    );
  }
}
