import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../main.dart';
import '../push.dart';
import '../state/alerts_state.dart';
import '../state/auth_state.dart';
import '../state/live_state.dart';
import '../state/market_state.dart';
import '../state/portfolio_state.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'alerts_view.dart';
import 'chain_view.dart';
import 'portfolio_view.dart';
import 'signals_view.dart';
import 'trade_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _signalsTab = 2, _alertsTab = 3;
  int _tab = 0;
  late final MarketState _market;
  late final PortfolioState _portfolio;
  late final LiveState _strategy;
  late final AlertsState _alerts;
  late final AuthState _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthState>();
    _market = context.read<MarketState>();
    _portfolio = context.read<PortfolioState>();
    _strategy = context.read<LiveState>();
    _alerts = context.read<AlertsState>();

    _market.onAuthLost = _auth.sessionLost;
    _portfolio.onAuthLost = _auth.sessionLost;
    _strategy.onAuthLost = _auth.sessionLost;
    _market.onTick = _alerts.evaluate;
    _alerts.onFire = showBanner;
    _alerts.load();

    _market.start();
    _portfolio.start(); // the header always shows balance + running P&L
    Push.start(context.read<Api>(), (title, body) {
      showBanner(title, body);
      _strategy.refreshNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _market.start();
      _portfolio.start();
      if (_tab == _signalsTab) _strategy.start();
      _auth.refresh();
    } else if (state == AppLifecycleState.paused) {
      _market.stop();
      _portfolio.stop();
      _strategy.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _market.onAuthLost = null;
    _market.onTick = null;
    _portfolio.onAuthLost = null;
    _strategy.onAuthLost = null;
    _alerts.onFire = null;
    _market.reset();
    _portfolio.reset();
    _strategy.reset();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _tab = i);
    // The strategy feed and the slower Pro extras only run while Signals is on screen.
    if (i == _signalsTab) {
      _strategy.start();
    } else {
      _strategy.stop();
    }
    _market.setSignalsVisible(i == _signalsTab);
    if (i == _alertsTab) _alerts.clearUnread();
  }

  void _openAccount() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _AppBarHeader(onBell: () => _select(_alertsTab), onAccount: _openAccount),
          Expanded(
            child: IndexedStack(index: _tab, children: [
              const TradeView(),
              ChainView(onPicked: () => _select(0)),
              SignalsView(onUpgrade: _openAccount, onOpenPortfolio: () => _select(4)),
              AlertsView(onUpgrade: _openAccount),
              const PortfolioView(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: _NavBar(index: _tab, onTap: _select),
    );
  }
}

// ───────────────────────── header ─────────────────────────
class _AppBarHeader extends StatelessWidget {
  final VoidCallback onBell;
  final VoidCallback onAccount;
  const _AppBarHeader({required this.onBell, required this.onAccount});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final m = context.watch<MarketState>();
    final pf = context.watch<PortfolioState>();
    final unread = context.select<AlertsState, int>((a) => a.unread);
    final name = auth.email.contains('@') ? auth.email.split('@').first : auth.email;
    final running = _runningPl(pf, m);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0D1116), C.bg]),
        border: Border(bottom: BorderSide(color: C.border)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: onAccount,
            child: Container(
              width: 34, height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.goldBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.gold.withAlpha(90))),
              child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: T.disp(14, color: C.gold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onAccount,
              behavior: HitTestBehavior.opaque,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome back', style: T.body(11, color: C.muted)),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.disp(14.5, w: FontWeight.w600)),
              ]),
            ),
          ),
          _HeadPill(
            text: m.marketOpen ? 'LIVE' : 'CLOSED',
            color: C.muted,
            leading: _PulseDot(color: m.marketOpen ? C.green : C.red, pulse: m.marketOpen),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAccount,
            child: _HeadPill(
              text: auth.subscribed ? 'PRO · ${auth.daysLeft}d' : 'FREE',
              color: auth.subscribed ? C.gold : C.muted,
              gold: auth.subscribed,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onBell,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: C.panelHi, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                child: const Icon(Icons.notifications_none_rounded, size: 18, color: C.muted),
              ),
              if (unread > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: C.red, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.bg, width: 2)),
                    child: Text(unread > 9 ? '9+' : '$unread', style: T.body(9, w: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BALANCE', style: T.label(C.muted)),
              Text(pf.hasData ? fmtInr(pf.balance) : '—', style: T.mono(14.5)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('RUNNING P&L', style: T.label(C.muted)),
            Text(pf.hasData ? fmtInr(running, sign: true) : '—', style: T.mono(14.5, color: C.pnl(running))),
          ]),
        ]),
        const SizedBox(height: 10),
        _Ticker(m: m),
        const SizedBox(height: 3),
        _Freshness(m: m),
      ]),
    );
  }

  /// Open P&L, re-priced from the 2-second chain feed between portfolio refreshes.
  static double _runningPl(PortfolioState pf, MarketState m) {
    var total = 0.0;
    for (final p in pf.positions) {
      final live = asD(m.legFor(asI(p['strike']), asS(p['option_type']))?['ltp']);
      final ltp = live ?? asD(p['ltp']) ?? 0;
      total += (ltp - (asD(p['buy_price']) ?? 0)) * asI(p['qty']);
    }
    return total;
  }
}

class _HeadPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool gold;
  final Widget? leading;
  const _HeadPill({required this.text, required this.color, this.gold = false, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: gold ? C.goldBg : C.panelHi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold ? C.gold.withAlpha(90) : C.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 5)],
        Text(text, style: T.body(10.5, w: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulseDot({required this.color, required this.pulse});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: widget.pulse ? 1 - _c.value * .65 : 1,
        child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      ),
    );
  }
}

class _Ticker extends StatelessWidget {
  final MarketState m;
  const _Ticker({required this.m});

  @override
  Widget build(BuildContext context) {
    final up = (m.change ?? 0) >= 0;
    final g = m.golden;
    final sig = asS(g?['signal'], 'WAIT');
    final ledColor = sig == 'BUY_CALL' ? C.green : (sig == 'BUY_PUT' ? C.red : C.dim);
    final sigText = !m.subscribed
        ? 'SIGNAL 🔒'
        : (sig == 'BUY_CALL' || sig == 'BUY_PUT')
            ? '${sig.replaceAll('_', ' ')} · ${asI(g?['strength'])}%'
            : 'WAIT';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: C.panel, border: Border.all(color: C.border), borderRadius: BorderRadius.circular(12)),
        child: IntrinsicHeight(
          child: Row(children: [
            Container(width: 3, color: C.gold),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                child: Row(children: [
                  Text('NIFTY', style: T.disp(13.5, spacing: .3)),
                  const SizedBox(width: 9),
                  Text(m.spot == null ? '--' : fmtNum(m.spot), style: T.mono(17)),
                  const SizedBox(width: 8),
                  if (m.change != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: up ? C.greenBg : C.redBg, borderRadius: BorderRadius.circular(6)),
                      child: Text('${fmtPts(m.change, dp: 2)} (${fmtPts(m.changePct, dp: 2)}%)',
                          style: T.mono(11, color: up ? C.green : C.red)),
                    ),
                  const Spacer(),
                  Flexible(
                    child: Text(sigText, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: T.body(10.5, w: FontWeight.w600, color: C.muted)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: ledColor,
                      shape: BoxShape.circle,
                      boxShadow: ledColor == C.dim ? null : [BoxShadow(color: ledColor, blurRadius: 8)],
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "updated Ns ago" line; re-renders each second on its own.
class _Freshness extends StatefulWidget {
  final MarketState m;
  const _Freshness({required this.m});
  @override
  State<_Freshness> createState() => _FreshnessState();
}

class _FreshnessState extends State<_Freshness> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.m.lastOk;
    String text;
    var stale = false;
    if (last == null) {
      text = '● connecting…';
      stale = true;
    } else {
      final secs = DateTime.now().difference(last).inSeconds;
      if (!widget.m.marketOpen) {
        text = '○ market closed · last update ${secs}s ago';
      } else if (secs <= 3) {
        text = '● live market data · updated just now';
      } else if (secs <= 10) {
        text = '● live market data · updated ${secs}s ago';
      } else {
        text = '⚠ reconnecting… last update ${secs}s ago';
        stale = true;
      }
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Text(text, style: T.mono(9.5, w: FontWeight.w400, color: stale ? C.gold : C.muted)),
    );
  }
}

// ───────────────────────── bottom nav ─────────────────────────
class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  static const _items = [
    (Icons.show_chart_rounded, 'Trade'),
    (Icons.table_rows_outlined, 'Chain'),
    (Icons.star_outline_rounded, 'Signals'),
    (Icons.notifications_none_rounded, 'Alerts'),
    (Icons.bar_chart_rounded, 'Portfolio'),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = context.select<AlertsState, int>((a) => a.unread);
    return Container(
      decoration: const BoxDecoration(color: Color(0xF00D1116), border: Border(top: BorderSide(color: C.border))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 9, bottom: 7),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(_items[i].$1, size: 21, color: i == index ? C.gold : C.dim),
                      if (i == 3 && unread > 0)
                        Positioned(
                          top: -1, right: -3,
                          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(_items[i].$2, style: T.body(9.5, w: FontWeight.w600, color: i == index ? C.gold : C.dim)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
