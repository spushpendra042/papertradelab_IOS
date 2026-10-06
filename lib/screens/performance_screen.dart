import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  Map<String, dynamic>? _perf;
  int _lotSize = 65;
  String? _error;
  int _lots = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().performance();
      if (!mounted) return;
      setState(() {
        _perf = asMap(r['performance']);
        _lotSize = asI(r['lot_size'], 65);
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.isAuth) {
        if (mounted) context.read<AuthState>().sessionLost();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _perf;
    if (p == null) {
      if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    final total = asI(p['total_trades']);
    final wins = asI(p['wins']), losses = asI(p['losses']), be = asI(p['breakeven']);
    final net = asD(p['net_pts']) ?? 0;
    final equity = asList(p['equity']).map((e) => asD(e) ?? 0).toList();
    final months = asList(p['months']);
    final sides = asMap(p['sides']);

    return PageBody(
      onRefresh: _load,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 2),
          child: Text('Track record', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
              total == 0
                  ? 'Every signal is recorded here automatically the moment it closes — wins and losses alike.'
                  : 'Every signal since ${fmtDate(p['since'])}, recorded automatically. Nothing is hidden or edited.',
              style: const TextStyle(color: C.muted, fontSize: 13)),
        ),
        const SizedBox(height: 14),
        StatGrid(children: [
          StatTile(
              label: 'Win rate',
              value: p['win_rate'] == null ? '—' : '${fmtNum(asD(p['win_rate']), dp: 1)}%',
              hint: p['win_rate_excl_breakeven'] == null
                  ? null
                  : '${fmtNum(asD(p['win_rate_excl_breakeven']), dp: 1)}% excl. breakeven'),
          StatTile(label: 'Total signals', value: '$total', hint: '$wins W · $losses L · $be BE'),
          StatTile(label: 'Net points', value: fmtPts(net), valueColor: C.pnl(net)),
          StatTile(
              label: 'Profit factor',
              value: fmtNum(asD(p['profit_factor'])),
              hint: 'gross profit ÷ gross loss'),
          StatTile(label: 'Avg per signal', value: fmtPts(asD(p['avg_pts'])), valueColor: C.pnl(asD(p['avg_pts']))),
          StatTile(label: 'Max drawdown', value: fmtPts(asD(p['max_drawdown_pts'])), valueColor: C.red, hint: 'worst peak-to-valley'),
          StatTile(label: 'Avg win / loss', value: '${fmtPts(asD(p['avg_win']), dp: 0)} / ${fmtPts(asD(p['avg_loss']), dp: 0)}'),
          StatTile(
              label: 'Current streak',
              value: asI(p['streak']) == 0 ? '—' : '${asI(p['streak']).abs()} ${asI(p['streak']) > 0 ? 'wins' : 'losses'}',
              valueColor: C.pnl(asI(p['streak']))),
        ]),
        if (total > 0) ...[
          const SectionTitle('Outcome split'),
          _SplitBar(wins: wins, losses: losses, be: be),
        ],
        const SectionTitle('Equity curve (points)'),
        Panel(child: EquityChart(values: equity)),
        const SectionTitle('What would it have made?'),
        _Calculator(
          netPts: net,
          lots: _lots,
          lotSize: _lotSize,
          onChanged: (v) => setState(() => _lots = v),
        ),
        if (sides.isNotEmpty) ...[
          const SectionTitle('By direction'),
          Panel(
            child: Column(children: [
              for (final k in sides.keys)
                _BreakdownRow(
                  label: '$k signals',
                  trades: asI(asMap(sides[k])['trades']),
                  wins: asI(asMap(sides[k])['wins']),
                  pts: asD(asMap(sides[k])['pts']) ?? 0,
                ),
            ]),
          ),
        ],
        if (months.isNotEmpty) ...[
          const SectionTitle('Month by month'),
          Panel(
            child: Column(children: [
              for (final m in months)
                _BreakdownRow(
                  label: fmtMonth(asS(asMap(m)['month'])),
                  trades: asI(asMap(m)['trades']),
                  wins: asI(asMap(m)['wins']),
                  pts: asD(asMap(m)['pts']) ?? 0,
                ),
            ]),
          ),
        ],
        const Disclaimer(
            'Points are NIFTY spot points between signal entry and exit on a paper account, before brokerage, '
            'slippage and taxes. ${AppConfig.disclaimer}'),
      ],
    );
  }
}

class _SplitBar extends StatelessWidget {
  final int wins, losses, be;
  const _SplitBar({required this.wins, required this.losses, required this.be});

  @override
  Widget build(BuildContext context) {
    Widget seg(int n, Color c) => n == 0
        ? const SizedBox.shrink()
        : Expanded(flex: n, child: Container(height: 10, color: c));
    Widget legend(String t, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(color: C.muted, fontSize: 12)),
        ]);
    return Panel(
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(children: [seg(wins, C.green), seg(be, C.amber), seg(losses, C.red)]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [
          legend('$wins target / profit', C.green),
          legend('$be stopped at entry', C.amber),
          legend('$losses stoploss', C.red),
        ]),
      ]),
    );
  }
}

class _Calculator extends StatelessWidget {
  final double netPts;
  final int lots;
  final int lotSize;
  final ValueChanged<int> onChanged;
  const _Calculator({required this.netPts, required this.lots, required this.lotSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rupees = netPts * lots * lotSize;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Lots', style: TextStyle(color: C.muted)),
          const Spacer(),
          IconButton(
              onPressed: lots > 1 ? () => onChanged(lots - 1) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(
              width: 36,
              child: Text('$lots',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(
              onPressed: lots < 50 ? () => onChanged(lots + 1) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ]),
        const SizedBox(height: 4),
        Text(fmtInr(rupees, sign: true),
            style: TextStyle(color: C.pnl(rupees), fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            '${fmtPts(netPts)} pts × $lots lot${lots == 1 ? '' : 's'} × $lotSize qty, if the index points were captured '
            '1:1 (e.g. futures). Before costs. Option premiums move less than the index.',
            style: const TextStyle(color: C.muted, fontSize: 12, height: 1.35)),
      ]),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int trades, wins;
  final double pts;
  const _BreakdownRow({required this.label, required this.trades, required this.wins, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600))),
        Text('$trades signals · $wins won', style: const TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(width: 14),
        SizedBox(
          width: 78,
          child: Text(fmtPts(pts),
              textAlign: TextAlign.right, style: TextStyle(color: C.pnl(pts), fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
