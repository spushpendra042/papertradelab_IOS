import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../main.dart';
import '../state/auth_state.dart';
import '../state/market_state.dart';
import '../state/portfolio_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'positions_list.dart';

class PortfolioView extends StatefulWidget {
  const PortfolioView({super.key});
  @override
  State<PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends State<PortfolioView> {
  int _seg = 0;
  Map<String, dynamic> _stat = {}, _today = {};
  bool _histLoading = false;

  Future<void> _loadHistory() async {
    if (_histLoading) return;
    setState(() => _histLoading = true);
    final api = context.read<Api>();
    try {
      final r = await Future.wait([api.statement(), api.tradeStats()]);
      if (!mounted) return;
      setState(() {
        _stat = r[0];
        _today = r[1];
      });
    } on ApiException catch (e) {
      if (e.isAuth && mounted) context.read<AuthState>().sessionLost();
    } finally {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  Future<void> _reset() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: C.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => const _ResetSheet(),
    );
    if (amount == null || !mounted) return;
    try {
      final r = await context.read<Api>().resetAccount(amount);
      if (!mounted) return;
      context.read<PortfolioState>().apply(asMap(r['portfolio']));
      setState(() {
        _stat = {};
        _today = {};
      });
      final left = asI(r['resets_left_today']);
      showBanner(asS(r['message'], 'Account reset'), '$left reset${left == 1 ? '' : 's'} left today.');
    } on ApiException catch (e) {
      showBanner('Reset failed', e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = context.watch<PortfolioState>();
    final m = context.watch<MarketState>();
    if (!pf.hasData) {
      if (pf.error != null) return ErrorRetry(message: pf.error!, onRetry: pf.refreshNow);
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    var running = 0.0;
    for (final p in pf.positions) {
      final ltp = asD(m.legFor(asI(p['strike']), asS(p['option_type']))?['ltp']) ?? asD(p['ltp']) ?? 0;
      running += (ltp - (asD(p['buy_price']) ?? 0)) * asI(p['qty']);
    }
    final today = asD(pf.data['realized_today']) ?? 0;
    final overall = asD(_stat['net_pl']);

    return PageBody(
      onRefresh: () async {
        await pf.refreshNow();
        if (_seg == 1) await _loadHistory();
      },
      children: [
        const SectionTitle('Portfolio'),
        Grid2(children: [
          Stat('Balance', fmtInr(pf.balance)),
          Stat('Running P&L', fmtInr(running, sign: true), color: C.pnl(running)),
          Stat("Today's booked P&L", fmtInr(today, sign: true), color: C.pnl(today)),
          Stat('Net worth', fmtInr(pf.balance + (asD(pf.data['invested']) ?? 0) + running)),
        ]),
        const SizedBox(height: 12),
        SegTabs(
          labels: const ['Positions', 'History'],
          index: _seg,
          onChanged: (i) {
            setState(() => _seg = i);
            if (i == 1) _loadHistory();
          },
        ),
        if (_seg == 0) const PositionsList() else ..._history(overall),
        const SectionTitle('Account reset'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Start over with a fresh paper balance. Open positions and trade history are cleared.',
                style: T.body(12.5, color: C.muted, height: 1.5)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _reset, child: const Text('Reset account')),
          ]),
        ),
      ],
    );
  }

  List<Widget> _history(double? overall) {
    if (_stat.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: _histLoading
                ? const CircularProgressIndicator(strokeWidth: 2.5)
                : OutlinedButton(onPressed: _loadHistory, child: const Text('Load history')),
          ),
        ),
      ];
    }
    final rows = asList(_stat['rows']).map(asMap).toList(); // oldest → newest
    // streak
    var streak = 0;
    bool? lastWin;
    for (final r in rows.reversed) {
      final win = (asD(r['realized_pl']) ?? 0) >= 0;
      lastWin ??= win;
      if (win != lastWin) break;
      streak++;
    }
    // equity curve of the last 30 closed trades
    var cum = 0.0;
    final last30 = rows.length > 30 ? rows.sublist(rows.length - 30) : rows;
    final equity = [for (final r in last30) cum += (asD(r['realized_pl']) ?? 0)];

    return [
      Panel(
        child: Column(children: [
          const SizedBox(height: 6),
          Text('${fmtNum(asD(_stat['accuracy']) ?? 0, dp: 1)}%', style: T.disp(44, color: C.gold)),
          const SizedBox(height: 6),
          Text('OVERALL WIN ACCURACY · ALL-TIME', style: T.label(C.muted)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: streak >= 2 ? (lastWin == true ? C.greenBg : C.redBg) : C.panelHi,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
                rows.isEmpty
                    ? 'No trades yet'
                    : (streak >= 2
                        ? '${lastWin == true ? '🔥' : '⚠️'} $streak-trade ${lastWin == true ? 'win' : 'loss'} streak'
                        : 'Streak: none active'),
                style: T.body(11.5, w: FontWeight.w700,
                    color: streak >= 2 ? (lastWin == true ? C.green : C.red) : C.muted)),
          ),
          const SizedBox(height: 14),
          Grid2(children: [
            Stat('Total trades', '${asI(_stat['total_trades'])}'),
            Stat('Net P&L', fmtInr(overall, sign: true), color: C.pnl(overall)),
            Stat('Wins', '${asI(_stat['wins'])}', color: C.green),
            Stat('Losses', '${asI(_stat['losses'])}', color: C.red),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Grid2(children: [
        Stat("Today's trades", '${asI(_today['total_trades'])}'),
        Stat("Today's accuracy", '${fmtNum(asD(_today['accuracy']) ?? 0, dp: 0)}%', color: C.gold),
      ]),
      SectionTitle('Equity curve', trailing: Text('last 30 trades', style: T.body(11, w: FontWeight.w600, color: C.gold))),
      Panel(child: EquityChart(values: equity)),
      const SectionTitle('Recent closed trades'),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: rows.isEmpty
            ? const EmptyState(Icons.trending_up, 'No closed trades yet')
            : Column(children: [
                for (final r in rows.reversed.take(25))
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
                    child: Row(children: [
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${fmtNum(asD(r['strike']), dp: 0)} ${asS(r['otype'])}', style: T.body(12.5)),
                          TextSpan(text: '  · ${asS(r['date'])}', style: T.mono(11, w: FontWeight.w400, color: C.muted)),
                        ])),
                      ),
                      Text(fmtInr(asD(r['realized_pl']), sign: true),
                          style: T.mono(12.5, color: C.pnl(asD(r['realized_pl'])))),
                    ]),
                  ),
              ]),
      ),
    ];
  }
}

class _ResetSheet extends StatefulWidget {
  const _ResetSheet();
  @override
  State<_ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<_ResetSheet> {
  static const _amounts = <(double, String)>[
    (100000.0, '₹1 Lakh'), (200000.0, '₹2 Lakh'), (500000.0, '₹5 Lakh'), (1000000.0, '₹10 Lakh'),
  ];
  double? _amount;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, Color c) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(k, style: T.body(13, color: C.muted)),
            Text(v, style: T.mono(13, color: c)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_confirming ? 'Confirm reset' : 'Reset account balance', style: T.disp(18)),
          const SizedBox(height: 10),
          if (!_confirming) ...[
            Text('Choose your new starting balance. The reset happens immediately.',
                style: T.body(12.5, color: C.muted, height: 1.5)),
            const SizedBox(height: 14),
            Grid2(children: [
              for (final a in _amounts)
                GestureDetector(
                  onTap: () => setState(() => _amount = a.$1),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _amount == a.$1 ? C.goldBg : C.panelHi,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _amount == a.$1 ? C.gold : C.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.$2, style: T.body(13, w: FontWeight.w700)),
                      Text(fmtInr(a.$1), style: T.mono(10.5, w: FontWeight.w400, color: C.muted)),
                    ]),
                  ),
                ),
            ]),
          ] else ...[
            row('New balance', fmtInr(_amount), C.text),
            row('Open positions', 'Will be cleared', C.red),
            row('Trade history', 'Will be cleared', C.red),
            const SizedBox(height: 8),
            Text("This can't be undone.", style: T.body(12.5, color: C.muted)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  if (_confirming) {
                    setState(() => _confirming = false);
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text(_confirming ? 'Back' : 'Cancel', style: T.disp(14, color: C.muted)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _amount == null
                    ? null
                    : () {
                        if (_confirming) {
                          Navigator.pop(context, _amount);
                        } else {
                          setState(() => _confirming = true);
                        }
                      },
                child: Text(_confirming ? 'Confirm reset' : 'Continue'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
