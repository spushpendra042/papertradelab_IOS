import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../state/market_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ChainView extends StatelessWidget {
  final VoidCallback onPicked;
  const ChainView({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MarketState>();
    if (!m.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    String oi(dynamic leg) {
      final v = asD(asMap(leg)['oi']);
      return v == null ? '--' : '${(v / 1000).toStringAsFixed(1)}K';
    }

    String ltp(dynamic leg) {
      final v = asD(asMap(leg)['ltp']);
      return v == null ? '--' : v.toStringAsFixed(1);
    }

    Widget cell(String t, {TextAlign align = TextAlign.left, Color color = C.text, double size = 12, FontWeight w = FontWeight.w500, int flex = 10}) =>
        Expanded(flex: flex, child: Text(t, textAlign: align, style: T.mono(size, w: w, color: color)));

    return PageBody(
      onRefresh: m.refreshNow,
      children: [
        const SectionTitle('Live option chain (ATM ±10)'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              child: Row(children: [
                cell('OI', color: C.muted, size: 10),
                cell('CE LTP', align: TextAlign.right, color: C.muted, size: 10),
                cell('STRIKE', align: TextAlign.center, color: C.muted, size: 10, flex: 9),
                cell('PE LTP', color: C.muted, size: 10),
                cell('OI', align: TextAlign.right, color: C.muted, size: 10),
              ]),
            ),
            for (final r in m.chain)
              InkWell(
                onTap: () {
                  m.selectStrike(asI(r['strike']));
                  onPicked();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: asI(r['strike']) == m.atm ? C.goldBg : null,
                    border: const Border(bottom: BorderSide(color: C.border)),
                  ),
                  child: Row(children: [
                    cell(oi(r['ce']), color: C.dim, size: 10.5),
                    cell(ltp(r['ce']), align: TextAlign.right, color: C.green),
                    cell('${asI(r['strike'])}', align: TextAlign.center, color: C.gold, w: FontWeight.w700, flex: 9),
                    cell(ltp(r['pe']), color: C.red),
                    cell(oi(r['pe']), align: TextAlign.right, color: C.dim, size: 10.5),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Tap a row to trade that strike.', textAlign: TextAlign.center, style: T.body(11, color: C.dim)),
      ],
    );
  }
}
