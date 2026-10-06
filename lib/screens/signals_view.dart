import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../format.dart';
import '../state/market_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'signals_screen.dart';

String _clean(dynamic s) {
  final t = asS(s).replaceAll(RegExp(r'[^\x00-\x7F]'), '').trim();
  return t.isEmpty ? '--' : t;
}

class SignalsView extends StatefulWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onOpenPortfolio;
  const SignalsView({super.key, required this.onUpgrade, required this.onOpenPortfolio});
  @override
  State<SignalsView> createState() => _SignalsViewState();
}

class _SignalsViewState extends State<SignalsView> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MarketState>();
    final upgrade = AppConfig.canPurchaseInApp ? widget.onUpgrade : null;
    Widget lock(String title, String text) => LockCard(title: title, text: text, onUpgrade: upgrade);

    List<Widget> body;
    if (_seg == 0) {
      body = [StrategyPane(onOpenAccount: widget.onUpgrade, onOpenTrade: widget.onOpenPortfolio)];
    } else if (!m.subscribed || m.pro == null) {
      body = [
        if (_seg == 1) ...[
          lock('Pro signals locked', 'Live execute / wait decision engine, golden entry signal and reversal watch.'),
          const SizedBox(height: 10),
          lock('Signal accuracy tracker', 'Real win-rate of every signal engine, tracked live.'),
        ],
        if (_seg == 2) ...[
          lock('Market structure', 'Live put-writing / call-writing / covering / unwinding read.'),
          const SizedBox(height: 10),
          lock('Operator bias, IV skew & OI walls', "Who's really in control, and where support and resistance sit."),
          const SizedBox(height: 10),
          lock('Trap detector', 'Fake breakout / breakdown detection near spot.'),
        ],
        if (_seg == 3) ...[
          lock('Risk dashboard', 'SL-hunt zones, per-position risk scoring and directional confidence.'),
          const SizedBox(height: 10),
          lock('FII / Pro multi-day trend', 'Institutional participant flow, 3-day trend.'),
        ],
      ];
    } else {
      final pro = m.pro!;
      body = _seg == 1 ? _signalPane(m, pro) : (_seg == 2 ? _structurePane(m, pro) : _riskPane(m));
    }

    return PageBody(
      onRefresh: m.refreshNow,
      children: [
        SegTabs(labels: const ['Strategy', 'Signal', 'Structure', 'Risk'], index: _seg, onChanged: (i) => setState(() => _seg = i)),
        ...body,
        const Disclaimer(AppConfig.disclaimer),
      ],
    );
  }

  // ───────────── Signal pane ─────────────
  List<Widget> _signalPane(MarketState m, Map<String, dynamic> pro) {
    final decision = asS(pro['final_decision']);
    final exec = decision.contains('EXECUTE');
    final noTrade = decision.contains('NO TRADE');
    final dColor = exec ? C.green : (noTrade ? C.red : C.gold);
    final g = m.golden ?? const <String, dynamic>{};
    final sig = asS(g['signal'], 'WAIT');
    final sigColor = sig == 'BUY_CALL' ? C.green : (sig == 'BUY_PUT' ? C.red : C.muted);
    final rev = asS(pro['reversal_hold']);
    final acc = asMap(pro['accuracy_tracker']);
    const accNames = {'spot_bias': 'Spot bias', 'trend_strength': 'Trend', 'operator_bias': 'Operator', 'final_decision': 'Final call'};

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: exec || noTrade ? dColor : C.goldDim, width: 1.5),
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [(exec || noTrade) ? dColor.withAlpha(31) : C.panel, C.panel]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('FINAL DECISION', style: T.label(C.muted)),
          const SizedBox(height: 6),
          Text(_clean(pro['final_decision']), style: T.disp(16, color: dColor)),
          if (pro['confidence'] != null) ...[
            const SizedBox(height: 6),
            Text('Confidence ${pro['confidence']}% · ${_clean(pro['signal_test'])}',
                style: T.mono(11.5, w: FontWeight.w400, color: C.muted)),
          ],
        ]),
      ),
      const SectionTitle('Golden signal'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: sigColor == C.muted ? C.panelHi : sigColor.withAlpha(31), borderRadius: BorderRadius.circular(9)),
              child: Text(sig.replaceAll('_', ' '), style: T.disp(19, color: sigColor)),
            ),
            const Spacer(),
            Text('conf ${asI(g['confirm_count'])}/${asI(g['confirm_needed'], 2)}', style: T.mono(12, w: FontWeight.w400, color: C.muted)),
          ]),
          const SizedBox(height: 12),
          StrengthBar(label: 'STRENGTH', pct: asD(g['strength']) ?? 0),
          const SizedBox(height: 10),
          Text(asS(g['reason'], 'Waiting for live signal…'), style: T.body(12.5, color: C.muted, height: 1.5)),
          if (asList(g['conditions']).isNotEmpty) const SizedBox(height: 10),
          for (final c in asList(g['conditions']).map(asMap))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 15, height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c['met'] == true ? C.greenBg : C.panelHi, borderRadius: BorderRadius.circular(5)),
                  child: Text(c['met'] == true ? '✓' : '·',
                      style: T.body(9, w: FontWeight.w700, color: c['met'] == true ? C.green : C.dim)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(asS(c['label']), style: T.body(12))),
                Text(asS(c['value']), style: T.mono(11, w: FontWeight.w400, color: C.muted)),
              ]),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Tag('Strike ${asS(g['strike'], '--')}'),
            Tag('Trend ${asS(g['trend'], asS(pro['trend_strength'], '--'))}'),
            Tag('Structure ${asS(g['market_structure'], '--')}'),
            Tag('OI ${asS(g['oi_combo'], '--')}'),
          ]),
        ]),
      ),
      const SectionTitle('Reversal / swing watch'),
      Panel(
        child: Text((rev.isNotEmpty && rev != 'WAIT') ? '🔁 $rev' : 'WAIT — no reversal setup active.',
            style: T.body(13, color: C.muted, height: 1.5)),
      ),
      SectionTitle('Signal accuracy tracker',
          trailing: Text('live, since market open', style: T.body(11, w: FontWeight.w600, color: C.gold))),
      Grid2(children: [
        for (final e in accNames.entries)
          Builder(builder: (_) {
            final s = asMap(acc[e.key]);
            final a = asD(s['accuracy']) ?? 0;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: C.panelHi, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e.value.toUpperCase(), style: T.label(C.muted))),
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(color: s['active'] == true ? C.green : C.dim, shape: BoxShape.circle),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('${a.toStringAsFixed(0)}%',
                    style: T.mono(18, w: FontWeight.w700, color: a >= 60 ? C.green : ((a > 0 && a < 45) ? C.red : C.text))),
                Text('${asI(s['win'])}W / ${asI(s['loss'])}L · ${asI(s['total'])} sig',
                    style: T.mono(10, w: FontWeight.w400, color: C.muted)),
              ]),
            );
          }),
      ]),
    ];
  }

  // ───────────── Structure pane ─────────────
  List<Widget> _structurePane(MarketState m, Map<String, dynamic> pro) {
    final oi = asMap(pro['oi_30m_signal']);
    const map = {
      'PUT_WRITING_BULLISH': ('🟢', 'Put Writing Support'),
      'CALL_WRITING_BEARISH': ('🔴', 'Call Writing Pressure'),
      'SHORT_COVERING': ('🟢', 'Short Covering'),
      'LONG_UNWINDING': ('🔴', 'Long Unwinding'),
      'SIDEWAYS': ('⚪', 'Sideways / Range'),
    };
    final ms = asS(oi['market_structure']);
    final entry = map[ms] ?? ('⚪', ms.isEmpty || ms == '-' ? 'No Data' : ms);
    final sig = asS(oi['signal'], 'WAIT');
    final sigColor = sig.contains('BULLISH') ? C.green : (sig.contains('BEARISH') ? C.red : C.muted);
    final tags = <Widget>[
      if (oi['bullish_acceleration'] == true) const Tag('⚡ Bullish acceleration', on: true),
      if (oi['bearish_acceleration'] == true) const Tag('⚡ Bearish acceleration', on: true),
      if (oi['price_compressed'] == true) const Tag('🎯 Price compressed'),
      if (oi['bullish_trap'] == true) const Tag('🪤 Bullish trap risk', on: true),
      if (oi['bearish_trap'] == true) const Tag('🪤 Bearish trap risk', on: true),
    ];

    // IV skew — same thresholds as the web app, from per-strike IV near ATM
    final near = m.chain.where((r) => (asI(r['strike']) - m.atm).abs() <= 200);
    final ceIv = near.map((r) => asD(asMap(r['ce'])['vol']) ?? 0).where((v) => v > 0).toList();
    final peIv = near.map((r) => asD(asMap(r['pe'])['vol']) ?? 0).where((v) => v > 0).toList();
    final avgCe = ceIv.isEmpty ? 0.0 : ceIv.reduce((a, b) => a + b) / ceIv.length;
    final avgPe = peIv.isEmpty ? 0.0 : peIv.reduce((a, b) => a + b) / peIv.length;
    final skew = avgPe - avgCe;
    final ivText = skew > 1.5
        ? 'PUT SKEW · Bearish IV pressure'
        : (skew < -1.5 ? 'CALL SKEW · Bullish IV pressure' : 'NEUTRAL · IV balanced');

    final support = asI(asMap(pro['support_wall'])['strike']);
    final resist = asI(asMap(pro['resistance_wall'])['strike']);
    var maxOi = 1.0;
    for (final r in m.chain) {
      for (final s in ['ce', 'pe']) {
        final v = asD(asMap(r[s])['oi']) ?? 0;
        if (v > maxOi) maxOi = v;
      }
    }

    return [
      const SectionTitle('Market structure (30-min OI flow)'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: C.panelHi, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
              child: Text(entry.$1, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.$2, style: T.disp(15)),
                Text(sig, style: T.body(11.5, w: FontWeight.w600, color: sigColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          StrengthBar(label: 'FLOW STRENGTH', pct: asD(oi['strength']) ?? 0),
          const SizedBox(height: 10),
          Text(asS(oi['reason'], '--'), style: T.body(12.5, color: C.muted, height: 1.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: tags.isEmpty ? [const Tag('No acceleration detected')] : tags),
          const SizedBox(height: 12),
          Grid2(children: [
            Stat('CE OI (30m)', oi['ce_30m_change'] == null ? '--' : fmtNum(asD(oi['ce_30m_change']), dp: 0)),
            Stat('PE OI (30m)', oi['pe_30m_change'] == null ? '--' : fmtNum(asD(oi['pe_30m_change']), dp: 0)),
          ]),
        ]),
      ),
      const SectionTitle('Operator bias & PCR'),
      Panel(
        child: Grid2(children: [
          Stat('Operator bias', '${_clean(pro['operator_bias'])}${pro['operator_score'] != null ? ' · ${pro['operator_score']}' : ''}',
              color: C.gold, mono: false),
          Stat('Trap status', _clean(pro['trap_status']), mono: false),
          Stat('Smart PCR', asS(pro['smart_pcr'], '--')),
          Stat('Session PCR', asS(pro['session_pcr'], '--')),
        ]),
      ),
      const SectionTitle('IV skew analysis'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Grid2(children: [
            Stat('Avg CE IV', '${avgCe.toStringAsFixed(2)}%', color: C.green),
            Stat('Avg PE IV', '${avgPe.toStringAsFixed(2)}%', color: C.red),
          ]),
          const SizedBox(height: 12),
          _SkewGauge(skew: skew),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final t in ['CALL SKEW', 'NEUTRAL', 'PUT SKEW']) Text(t, style: T.mono(10, w: FontWeight.w400, color: C.muted)),
          ]),
          const SizedBox(height: 10),
          Text('$ivText (skew ${skew.toStringAsFixed(2)})', style: T.body(12.5, color: C.muted)),
        ]),
      ),
      const SectionTitle('OI wall heatmap'),
      Panel(
        child: Column(children: [
          Grid2(children: [
            Stat('Support wall', support == 0 ? '--' : '$support', color: C.green),
            Stat('Resistance wall', resist == 0 ? '--' : '$resist', color: C.red),
          ]),
          const SizedBox(height: 12),
          for (final r in m.chain)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: _HeatBar(frac: (asD(asMap(r['ce'])['oi']) ?? 0) / maxOi, color: C.green, alignEnd: true)),
                SizedBox(
                  width: 58,
                  child: Text('${asI(r['strike'])}',
                      textAlign: TextAlign.center,
                      style: T.mono(11, w: FontWeight.w700, color: C.gold).copyWith(
                          shadows: (asI(r['strike']) == support || asI(r['strike']) == resist)
                              ? const [Shadow(color: C.gold, blurRadius: 6)]
                              : null)),
                ),
                Expanded(child: _HeatBar(frac: (asD(asMap(r['pe'])['oi']) ?? 0) / maxOi, color: C.red, alignEnd: false)),
              ]),
            ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('■ CE OI (calls)', style: T.body(10, color: C.muted)),
            Text('PE OI (puts) ■', style: T.body(10, color: C.muted)),
          ]),
        ]),
      ),
      const SectionTitle('Trap detector'),
      Panel(
        child: m.traps.isEmpty
            ? Text('No traps detected — clean tape.', style: T.body(12.5, color: C.muted))
            : Column(children: [
                for (final t in m.traps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Pill(t['side'] == 'bull' ? 'BULLISH TRAP' : 'BEARISH TRAP', color: t['side'] == 'bull' ? C.green : C.red),
                      const SizedBox(width: 10),
                      Text('Strike ${t['strike']}', style: T.mono(12)),
                      const Spacer(),
                      Text('CE ${fmtPts(asD(t['ce_change']), dp: 0)} / PE ${fmtPts(asD(t['pe_change']), dp: 0)}',
                          style: T.mono(10.5, w: FontWeight.w400, color: C.muted)),
                    ]),
                  ),
              ]),
      ),
    ];
  }

  // ───────────── Risk pane ─────────────
  List<Widget> _riskPane(MarketState m) {
    final dir = asS(m.overall['signal'], '--');
    final dirColor = RegExp('bullish', caseSensitive: false).hasMatch(dir)
        ? C.green
        : (RegExp('bearish', caseSensitive: false).hasMatch(dir) ? C.red : C.muted);
    String zone(dynamic z) => asList(z).isEmpty ? '--' : asList(z).join(' – ');
    final p = m.participant;
    final days = asList(p['recent_days']).map(asMap).take(3).toList().reversed.toList();
    var maxAbs = 1.0;
    for (final d in days) {
      final v = (asD(d['total_net']) ?? 0).abs();
      if (v > maxAbs) maxAbs = v;
    }
    final riskKeys = m.slRisk.keys.where((k) => m.slRisk[k] is Map).toList();

    Color riskColor(String label) {
      final l = label.toLowerCase();
      if (l.contains('extreme') || l.contains('high')) return C.red;
      if (l.contains('moderate')) return C.gold;
      return C.green;
    }

    return [
      const SectionTitle('Overall directional confidence'),
      Panel(child: Text(dir, style: T.body(14, w: FontWeight.w600, color: dirColor))),
      const SectionTitle('SL hunt zones'),
      Panel(
        child: Grid2(children: [
          Stat('Major support', asS(m.slLevels['major_support'], '--'), color: C.green),
          Stat('Major resistance', asS(m.slLevels['major_resistance'], '--'), color: C.red),
          Stat('Support SL-hunt zone', zone(m.slLevels['support_sl_zone']), size: 13),
          Stat('Resistance SL-hunt zone', zone(m.slLevels['resistance_sl_zone']), size: 13),
        ]),
      ),
      const SectionTitle('Your position risk'),
      Panel(
        child: riskKeys.isEmpty
            ? Text('No open positions to score.', style: T.body(12.5, color: C.muted))
            : Column(children: [
                for (final k in riskKeys)
                  Builder(builder: (_) {
                    final row = asMap(m.slRisk[k]);
                    final fin = asMap(row['final']);
                    final market = asMap(row['market']);
                    final label = asS(fin['label'], '--');
                    final factors = asList(market['market_factors']).join(' · ');
                    final c = riskColor(label);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(k.replaceAll('_', ' '), style: T.disp(13))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: c.withAlpha(31), borderRadius: BorderRadius.circular(20)),
                            child: Text('$label · ${asS(fin['score'], '0')}', style: T.body(10.5, w: FontWeight.w700, color: c)),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text(
                            [asS(market['market_context']), asS(asMap(row['position'])['label']), factors]
                                .where((x) => x.isNotEmpty)
                                .join(' · '),
                            style: T.body(11, color: C.muted, height: 1.5)),
                      ]),
                    );
                  }),
              ]),
      ),
      const SectionTitle('FII / Pro multi-day trend'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Grid2(children: [
            Stat('Final bias', asS(p['final_bias'], '--').toUpperCase(), color: C.gold, mono: false),
            Stat('Expected move', asS(p['expected_move'], '--'), size: 13),
          ]),
          const SizedBox(height: 10),
          Text(asS(p['comment'], '--'), style: T.body(12.5, color: C.muted, height: 1.5)),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in days)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        width: 34,
                        height: 6 + 54 * ((asD(d['total_net']) ?? 0).abs() / maxAbs),
                        decoration: BoxDecoration(
                          color: d['bias'] == 'bullish' ? C.green : (d['bias'] == 'bearish' ? C.red : C.dim),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(asS(d['date']).length > 6 ? asS(d['date']).substring(0, 6) : asS(d['date']),
                          style: T.mono(9, w: FontWeight.w400, color: C.muted)),
                    ]),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    ];
  }
}

class _HeatBar extends StatelessWidget {
  final double frac;
  final Color color;
  final bool alignEnd;
  const _HeatBar({required this.frac, required this.color, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(color: C.panelHi, borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(widthFactor: frac.clamp(0.0, 1.0), child: Container(color: color)),
    );
  }
}

class _SkewGauge extends StatelessWidget {
  final double skew;
  const _SkewGauge({required this.skew});

  @override
  Widget build(BuildContext context) {
    final pos = 0.5 + (skew.clamp(-5.0, 5.0) / 5) * 0.4;
    return LayoutBuilder(builder: (_, c) {
      return Container(
        height: 34,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: C.panelHi, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
        child: Stack(children: [
          Positioned.fill(
            child: Row(children: [
              Expanded(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, C.greenBg])))),
              Expanded(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [C.redBg, Colors.transparent])))),
            ]),
          ),
          Positioned(left: c.maxWidth / 2 - 1, top: 0, bottom: 0, child: Container(width: 2, color: C.border)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: (c.maxWidth * pos - 2).clamp(0.0, c.maxWidth - 6),
            top: 2, bottom: 2,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                  color: C.gold, borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(color: C.gold, blurRadius: 8)]),
            ),
          ),
        ]),
      );
    });
  }
}
