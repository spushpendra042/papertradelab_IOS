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

/// Open positions with live P&L and a Close button. Used on Trade and Portfolio.
class PositionsList extends StatefulWidget {
  const PositionsList({super.key});
  @override
  State<PositionsList> createState() => _PositionsListState();
}

class _PositionsListState extends State<PositionsList> {
  String? _closing;

  Future<void> _close(Map<String, dynamic> p, double pl) async {
    final strike = asI(p['strike']);
    final type = asS(p['option_type']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.panel,
        title: Text('Close NIFTY $strike $type?', style: T.disp(17)),
        content: Text('Sells all ${asI(p['qty'])} qty at the live price.\nCurrent P&L: ${fmtInr(pl, sign: true)}',
            style: T.body(13.5, color: C.muted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close position')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _closing = '$strike$type');
    try {
      final r = await context.read<Api>().sell(strike, type);
      if (!mounted) return;
      context.read<PortfolioState>().apply(asMap(r['portfolio']));
      showBanner('Position closed', asS(r['message']));
    } on ApiException catch (e) {
      if (e.isAuth && mounted) context.read<AuthState>().sessionLost();
      showBanner('Could not close', e.message);
    } finally {
      if (mounted) setState(() => _closing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = context.watch<PortfolioState>();
    final m = context.watch<MarketState>();
    final positions = pf.positions;
    if (positions.isEmpty) return const EmptyState(Icons.inbox_outlined, 'No open positions yet');

    return Column(children: [
      for (final p in positions)
        Builder(builder: (_) {
          final strike = asI(p['strike']);
          final type = asS(p['option_type']);
          final buy = asD(p['buy_price']) ?? 0;
          final ltp = asD(m.legFor(strike, type)?['ltp']) ?? asD(p['ltp']) ?? buy;
          final pl = (ltp - buy) * asI(p['qty']);
          final closing = _closing == '$strike$type';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('$strike $type', style: T.disp(15)),
                      if (p['is_auto'] == true) ...[const SizedBox(width: 8), Pill('AUTO', color: C.blue)],
                    ]),
                    const SizedBox(height: 3),
                    Text('Qty ${asI(p['qty'])} · Buy ₹${fmtNum(buy)} · LTP ₹${fmtNum(ltp)}',
                        style: T.mono(11, w: FontWeight.w400, color: C.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtInr(pl, sign: true), style: T.mono(15, w: FontWeight.w700, color: C.pnl(pl))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: closing ? null : () => _close(p, pl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: C.panelHi, borderRadius: BorderRadius.circular(7), border: Border.all(color: C.border)),
                      child: closing
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8))
                          : Text('Close', style: T.body(11, w: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        }),
    ]);
  }
}
