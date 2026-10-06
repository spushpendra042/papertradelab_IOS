import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../format.dart';
import '../state/live_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'performance_screen.dart';
import 'order_ticket.dart';
import 'plans_screen.dart';

/// The automated strategy's live signal (the old "Signals" tab), now one pane of the Signals view.
class StrategyPane extends StatelessWidget {
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenTrade;
  const StrategyPane({super.key, required this.onOpenAccount, required this.onOpenTrade});

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveState>();
    if (!live.hasData) {
      if (live.error != null) return ErrorRetry(message: live.error!, onRetry: live.refreshNow);
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    final pos = live.position;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (pos == null)
        _WaitingCard(marketOpen: live.marketOpen, rules: live.rules)
      else if (pos['locked'] == true)
        _LockedCard(onOpenAccount: onOpenAccount)
      else
        _PositionCard(pos: pos, rules: live.rules, marketOpen: live.marketOpen, onOpenTrade: onOpenTrade),
      _TodayStrip(today: live.today),
      const SectionTitle('Signal conditions right now'),
      _Meters(live: live, onOpenAccount: onOpenAccount),
      if (live.lastTrade != null && live.lastTrade!['status'] == 'CLOSED') ...[
        const SectionTitle('Last closed signal'),
        _LastTrade(t: live.lastTrade!),
      ],
      const SectionTitle('Strategy track record'),
      Grid2(children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(appBar: AppBar(title: const Text('Track record')), body: const SafeArea(child: PerformanceScreen())))),
          icon: const Icon(Icons.insights, size: 18, color: C.gold),
          label: const Text('Accuracy'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(appBar: AppBar(title: const Text('Signal history')), body: const SafeArea(child: HistoryScreen())))),
          icon: const Icon(Icons.receipt_long, size: 18, color: C.gold),
          label: const Text('All signals'),
        ),
      ]),
    ]);
  }
}

class _PositionCard extends StatelessWidget {
  final Map<String, dynamic> pos;
  final Map<String, dynamic> rules;
  final bool marketOpen;
  final VoidCallback onOpenTrade;
  const _PositionCard({required this.pos, required this.rules, required this.marketOpen, required this.onOpenTrade});

  @override
  Widget build(BuildContext context) {
    final sell = pos['side'] == 'SELL';
    final sideColor = sell ? C.red : C.green;
    final move = asD(pos['move_pts']) ?? 0;
    final be = pos['be_moved'] == true;
    final target = (asD(rules['target']) ?? 90).toDouble();
    return Panel(
      borderColor: sideColor.withAlpha(140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(sell ? 'SELL SIGNAL' : 'BUY SIGNAL', color: sideColor, icon: sell ? Icons.south_east : Icons.north_east),
              const SizedBox(width: 8),
              if (be) Pill('RISK-FREE', color: C.amber, icon: Icons.lock),
              const Spacer(),
              Text('since ${fmtTime(pos['entry_time'])}', style: const TextStyle(color: C.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text('NIFTY ${asS(pos['strike'])} ${asS(pos['option_type'])}',
              style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(sell ? 'Bearish view — index expected to fall' : 'Bullish view — index expected to rise',
              style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtPts(move),
                  style: TextStyle(color: C.pnl(move), fontSize: 38, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('pts', style: TextStyle(color: C.muted)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('P&L per lot', style: TextStyle(color: C.muted, fontSize: 11)),
                  Text(fmtInr(asD(pos['pnl_per_lot']), sign: true),
                      style: TextStyle(
                          color: C.pnl(asD(pos['pnl_per_lot'])), fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TradeProgressBar(movePts: move, slPts: be ? 0 : 15, targetPts: target),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(be ? 'SL at entry' : 'SL −${asS(rules['sl'], '15')}', style: const TextStyle(color: C.red, fontSize: 11)),
              Text('Target +${asS(rules['target'], '90')}', style: const TextStyle(color: C.green, fontSize: 11)),
            ],
          ),
          const Divider(height: 26),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            children: [
              KeyValue('Entry (spot)', fmtNum(asD(pos['entry_underlying']), dp: 0)),
              KeyValue('Stoploss', fmtNum(asD(pos['sl']), dp: 0), color: C.red),
              KeyValue('Target', fmtNum(asD(pos['target']), dp: 0), color: C.green),
              KeyValue('Option entry', '₹${fmtNum(asD(pos['entry_ltp']))}'),
              KeyValue('Option now', pos['ltp'] == null ? '—' : '₹${fmtNum(asD(pos['ltp']))}'),
              KeyValue('Best so far', '${fmtPts(asD(pos['best_move']))} pts'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: sideColor),
            onPressed: !marketOpen
                ? null
                : () async {
                    await showOrderTicket(context,
                        strike: asI(pos['strike']),
                        optionType: asS(pos['option_type']),
                        title: 'Follow this signal');
                  },
            icon: const Icon(Icons.flash_on),
            label: const Text('Follow in my paper account'),
          ),
          TextButton(onPressed: onOpenTrade, child: const Text('View my positions')),
          if (!be) ...[
            const SizedBox(height: 4),
            Text('Stoploss moves to entry once the trade reaches +${asS(rules['be_trigger'], '20')} pts.',
                style: const TextStyle(color: C.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  final bool marketOpen;
  final Map<String, dynamic> rules;
  const _WaitingCard({required this.marketOpen, required this.rules});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Icon(marketOpen ? Icons.radar : Icons.nightlight_round, color: C.accent, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marketOpen ? 'Scanning for the next signal' : 'Market is closed',
                    style: const TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    marketOpen
                        ? 'No open signal. New entries until ${asS(rules['entry_until'], '14:30')}, square-off at ${asS(rules['square_off'], '15:20')}.'
                        : 'Signals run 09:15–15:20 IST on trading days. You will be notified.',
                    style: const TextStyle(color: C.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final VoidCallback onOpenAccount;
  const _LockedCard({required this.onOpenAccount});

  @override
  Widget build(BuildContext context) {
    return Panel(
      borderColor: C.amber.withAlpha(140),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, color: C.amber, size: 36),
          const SizedBox(height: 10),
          const Text('A signal is live right now',
              style: TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Entry, stoploss, target and live P&L are visible to subscribers.',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
          const SizedBox(height: 14),
          if (AppConfig.canPurchaseInApp)
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
              child: const Text('Unlock signals'),
            )
          else
            OutlinedButton(onPressed: onOpenAccount, child: const Text('View subscription status')),
        ],
      ),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  final Map<String, dynamic> today;
  const _TodayStrip({required this.today});

  @override
  Widget build(BuildContext context) {
    final pts = asD(today['pts']) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            KeyValue('Closed today', '${asI(today['trades'])}'),
            KeyValue('Winners', '${asI(today['wins'])}'),
            KeyValue('Today\'s points', fmtPts(pts), color: C.pnl(pts)),
          ],
        ),
      ),
    );
  }
}

class _Meters extends StatelessWidget {
  final LiveState live;
  final VoidCallback onOpenAccount;
  const _Meters({required this.live, required this.onOpenAccount});

  Widget _full(String title, Color color, List<dynamic> items) {
    final met = items.where((e) => asMap(e)['ok'] == true).length;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('$met / ${items.length}', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: items.isEmpty ? 0 : met / items.length,
              minHeight: 5,
              backgroundColor: C.border,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(asMap(e)['ok'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18, color: asMap(e)['ok'] == true ? color : C.muted),
                const SizedBox(width: 10),
                Expanded(child: Text(asS(asMap(e)['label']), style: const TextStyle(color: C.text, fontSize: 13))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _teaser(String title, Color color, int met, int total) {
    return Panel(
      child: Row(children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('$met / $total conditions met', style: const TextStyle(color: C.text)),
        const SizedBox(width: 8),
        const Icon(Icons.lock_outline, size: 16, color: C.muted),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = live.meters;
    if (live.subscribed) {
      return Column(children: [
        _full('SELL setup', C.red, asList(m['sell'])),
        const SizedBox(height: 10),
        _full('BUY setup', C.green, asList(m['buy'])),
        const SizedBox(height: 8),
        const Text('A signal fires the moment every condition turns true on a fresh snapshot.',
            style: TextStyle(color: C.muted, fontSize: 12)),
      ]);
    }
    return Column(children: [
      _teaser('SELL setup', C.red, asI(m['sell_met']), asI(m['sell_total'])),
      const SizedBox(height: 10),
      _teaser('BUY setup', C.green, asI(m['buy_met']), asI(m['buy_total'])),
    ]);
  }
}

class _LastTrade extends StatelessWidget {
  final Map<String, dynamic> t;
  const _LastTrade({required this.t});

  @override
  Widget build(BuildContext context) {
    final pts = asD(t['pnl_pts']);
    final sell = t['side'] == 'SELL';
    return Panel(
      child: Row(children: [
        Pill(sell ? 'SELL' : 'BUY', color: sell ? C.red : C.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NIFTY ${asS(t['strike'])} ${asS(t['option_type'])}',
                style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
            Text('${fmtDateTime(t['exit_time'])} · ${asS(t['exit_reason'])}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: C.muted, fontSize: 12)),
          ]),
        ),
        Text('${fmtPts(pts)} pts', style: TextStyle(color: C.pnl(pts), fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}
