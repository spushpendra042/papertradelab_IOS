import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../greeks.dart';
import '../main.dart';
import '../state/auth_state.dart';
import '../state/market_state.dart';
import '../state/portfolio_state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'positions_list.dart';

class TradeView extends StatefulWidget {
  const TradeView({super.key});
  @override
  State<TradeView> createState() => _TradeViewState();
}

class _TradeViewState extends State<TradeView> {
  final _strikeScroll = ScrollController();
  bool _centered = false;
  bool _showPayoff = true;

  @override
  void dispose() {
    _strikeScroll.dispose();
    super.dispose();
  }

  void _centerOn(MarketState m) {
    if (_centered || m.chain.isEmpty || !_strikeScroll.hasClients) return;
    final idx = m.chain.indexWhere((r) => asI(r['strike']) == (m.selectedStrike ?? m.atm));
    if (idx < 0) return;
    _centered = true;
    const chipW = 78.0;
    final target = idx * chipW - (_strikeScroll.position.viewportDimension / 2) + chipW / 2;
    _strikeScroll.jumpTo(target.clamp(0.0, _strikeScroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MarketState>();
    if (!m.hasData) {
      if (m.error != null) return ErrorRetry(message: m.error!, onRetry: m.refreshNow);
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOn(m));

    final leg = m.selectedLeg;
    final ltp = asD(leg?['ltp']);
    final isCall = m.side == 'CE';
    final hist = m.spotHistory;
    final up = hist.length < 2 || hist.last >= hist.first;

    return PageBody(
      onRefresh: m.refreshNow,
      children: [
        // ── live spot chart ──
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('NIFTY 50', style: T.disp(14)),
                    const SizedBox(width: 7),
                    if (m.marketOpen) Text('● LIVE', style: T.body(9, w: FontWeight.w700, color: C.green)),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                      hist.length < 2
                          ? 'Session range —'
                          : 'Session range ${hist.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)} – '
                              '${hist.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}',
                      style: T.mono(10.5, w: FontWeight.w400, color: C.muted)),
                ]),
              ),
              Text(m.spot == null ? '--' : fmtNum(m.spot), style: T.mono(18, w: FontWeight.w700, color: up ? C.green : C.red)),
            ]),
            const SizedBox(height: 4),
            SpotSparkline(values: hist),
          ]),
        ),

        const SectionTitle('Option chain — pick a strike'),
        SizedBox(
          height: 42,
          child: ListView.builder(
            controller: _strikeScroll,
            scrollDirection: Axis.horizontal,
            itemCount: m.chain.length,
            itemBuilder: (_, i) {
              final s = asI(m.chain[i]['strike']);
              final active = s == m.selectedStrike;
              final atm = s == m.atm;
              return GestureDetector(
                onTap: () => m.selectStrike(s),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? C.gold : C.panelHi,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (active || atm) ? C.gold : C.border),
                  ),
                  child: Text('$s', style: T.mono(13, color: active ? C.onGold : (atm ? C.gold : C.muted))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // ── order card ──
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _SideButton(label: '▲ CALL (CE)', active: isCall, color: C.green, onTap: () => m.setSide('CE'))),
              const SizedBox(width: 8),
              Expanded(child: _SideButton(label: '▼ PUT (PE)', active: !isCall, color: C.red, onTap: () => m.setSide('PE'))),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Strike ${m.selectedStrike ?? '--'} · ${m.expiry.isEmpty ? '--' : m.expiry}',
                      style: T.mono(11, w: FontWeight.w400, color: C.muted)),
                  const SizedBox(height: 2),
                  Text(ltp == null ? '--' : '₹${fmtNum(ltp)}', style: T.mono(30, w: FontWeight.w700)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('OI ${_k(asD(leg?['oi']))}', style: T.mono(11, w: FontWeight.w400, color: C.muted)),
                const SizedBox(height: 4),
                Text('ΔOI ${_signed(asD(leg?['oi_delta']))}', style: T.mono(11, w: FontWeight.w400, color: C.muted)),
              ]),
            ]),
            const SizedBox(height: 12),
            _GreeksRow(m: m),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: C.panelHi, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              child: Row(children: [
                _QtyButton(icon: Icons.remove, onTap: m.lots > 1 ? () => m.stepLots(-1) : null),
                Expanded(
                  child: Column(children: [
                    Text('${m.lots} lot${m.lots == 1 ? '' : 's'}', style: T.mono(16, w: FontWeight.w700)),
                    Text('${m.lots * m.lotSize} qty', style: T.body(10, color: C.muted)),
                  ]),
                ),
                _QtyButton(icon: Icons.add, onTap: m.lots < 50 ? () => m.stepLots(1) : null),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.green, foregroundColor: const Color(0xFF052A1E), minimumSize: const Size.fromHeight(52)),
              onPressed: (!m.marketOpen || ltp == null) ? null : () => _confirmBuy(context, m, ltp),
              child: Text(m.marketOpen ? 'Buy' : 'Market closed'),
            ),
            const SizedBox(height: 8),
            Text(
                ltp == null
                    ? 'Estimated cost —'
                    : 'Estimated cost ≈ ${fmtInr(ltp * m.lots * m.lotSize)}',
                textAlign: TextAlign.center,
                style: T.body(11, color: C.muted)),
          ]),
        ),

        SectionTitle('Payoff at expiry',
            trailing: GestureDetector(
              onTap: () => setState(() => _showPayoff = !_showPayoff),
              child: Text(_showPayoff ? 'Hide' : 'Show', style: T.body(11, w: FontWeight.w600, color: C.gold)),
            )),
        if (_showPayoff)
          Panel(
            child: (ltp == null || m.selectedStrike == null || m.spot == null)
                ? Text('Pick a strike with a live price to see the payoff.', style: T.body(12.5, color: C.muted))
                : Column(children: [
                    PayoffChart(
                        strike: m.selectedStrike!.toDouble(),
                        premium: ltp,
                        spot: m.spot!,
                        qty: m.lots * m.lotSize,
                        isCall: isCall),
                    const SizedBox(height: 8),
                    Grid2(children: [
                      Stat('Breakeven', (isCall ? m.selectedStrike! + ltp : m.selectedStrike! - ltp).toStringAsFixed(0)),
                      Stat('Max loss (premium)', fmtInr(ltp * m.lots * m.lotSize), color: C.red),
                    ]),
                    const SizedBox(height: 8),
                    Text("Single-leg buy, valued at expiry. Doesn't include brokerage or STT.",
                        style: T.body(12, color: C.muted, height: 1.5)),
                  ]),
          ),

        const SectionTitle('Open positions'),
        const PositionsList(),
      ],
    );
  }

  static String _k(double? v) => v == null ? '--' : '${(v / 1000).toStringAsFixed(1)}K';
  static String _signed(double? v) => v == null ? '--' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(0)}';

  Future<void> _confirmBuy(BuildContext context, MarketState m, double ltp) async {
    final strike = m.selectedStrike;
    if (strike == null) return;
    final qty = m.lots * m.lotSize;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Confirm Buy', style: T.disp(18)),
            const SizedBox(height: 12),
            _SheetRow('Instrument', 'NIFTY $strike ${m.side}'),
            _SheetRow('Side', 'BUY'),
            _SheetRow('Qty', '$qty (${m.lots} lot${m.lots == 1 ? '' : 's'})'),
            _SheetRow('LTP', '₹${fmtNum(ltp)}'),
            _SheetRow('Est. value', fmtInr(ltp * qty)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: T.disp(14, color: C.muted)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.green, foregroundColor: const Color(0xFF052A1E), minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final r = await context.read<Api>().buy(strike, m.side, m.lots);
      if (!context.mounted) return;
      context.read<PortfolioState>().apply(asMap(r['portfolio']));
      showBanner('Order filled', asS(r['message']));
    } on ApiException catch (e) {
      if (e.isAuth && context.mounted) context.read<AuthState>().sessionLost();
      showBanner('Order failed', e.message);
    }
  }
}

class _SheetRow extends StatelessWidget {
  final String k, v;
  const _SheetRow(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: T.body(13, color: C.muted)),
        Text(v, style: T.mono(13)),
      ]),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _SideButton({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withAlpha(31) : C.panelHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : C.border),
        ),
        child: Text(label, style: T.disp(14, color: active ? color : C.muted, spacing: .2)),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: onTap == null ? C.dim : C.text),
      ),
    );
  }
}

class _GreeksRow extends StatelessWidget {
  final MarketState m;
  const _GreeksRow({required this.m});

  @override
  Widget build(BuildContext context) {
    final leg = m.selectedLeg;
    final iv = asD(leg?['vol']);
    Greeks? g;
    if (iv != null && iv > 0 && m.spot != null && m.selectedStrike != null) {
      g = blackScholes(
          spot: m.spot!, strike: m.selectedStrike!.toDouble(), ivPct: iv, isCall: m.side == 'CE', expiry: m.expiry);
    }
    Widget chip(String label, String value, [Color? color]) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
            decoration: BoxDecoration(
              color: C.panelHi, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.border)),
            child: Column(children: [
              Text(label.toUpperCase(), style: T.body(8.5, w: FontWeight.w600, color: C.muted)),
              const SizedBox(height: 2),
              FittedBox(child: Text(value, style: T.mono(12.5, w: FontWeight.w700, color: color ?? C.text))),
            ]),
          ),
        );
    return Row(children: [
      chip('Delta', g == null ? '--' : g.delta.toStringAsFixed(3)),
      chip('Gamma', g == null ? '--' : g.gamma.toStringAsFixed(5)),
      chip('Theta/day', g == null ? '--' : '${g.theta >= 0 ? '+' : ''}${g.theta.toStringAsFixed(2)}',
          g == null ? null : (g.theta < 0 ? C.red : C.green)),
      chip('IV', iv == null || iv <= 0 ? '--' : '${iv.toStringAsFixed(1)}%'),
    ]);
  }
}
