import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../format.dart';
import '../main.dart';
import '../state/alerts_state.dart';
import '../state/market_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AlertsView extends StatelessWidget {
  final VoidCallback onUpgrade;
  const AlertsView({super.key, required this.onUpgrade});

  static const _icons = {'price': '💰', 'oi': '📊', 'signal': '⚡', 'trap': '🪤'};

  Color _kindColor(String k) {
    switch (k) {
      case 'price':
        return C.blue;
      case 'bull':
      case 'signal':
        return C.green;
      case 'bear':
      case 'trap':
        return C.red;
    }
    return C.gold;
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AlertsState>();
    final pro = context.select<MarketState, bool>((m) => m.subscribed);
    return Stack(children: [
      PageBody(
        onRefresh: () async {},
        children: [
          const SectionTitle('Smart alerts'),
          if (!pro)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                  color: C.goldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.gold.withAlpha(90))),
              child: Row(children: [
                Expanded(
                  child: Text('${a.activeCount} / $kFreeAlertLimit free alerts used',
                      style: T.body(12, w: FontWeight.w600, color: C.gold)),
                ),
                if (AppConfig.canPurchaseInApp)
                  GestureDetector(
                    onTap: onUpgrade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(8)),
                      child: Text('Go Pro', style: T.disp(11.5, color: C.onGold)),
                    ),
                  ),
              ]),
            ),
          if (a.alerts.isEmpty)
            const EmptyState(Icons.notifications_none_rounded, 'No alerts yet — tap + to create one')
          else
            for (final al in a.alerts)
              Opacity(
                opacity: (al['muted'] == true || al['active'] != true) ? .45 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _kindColor(asS(al['type'])).withAlpha(31), borderRadius: BorderRadius.circular(10)),
                        child: Text(_icons[asS(al['type'])] ?? '🔔', style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(AlertsState.label(al), style: T.body(13, w: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(al['active'] == true ? AlertsState.sub(al) : 'Triggered — no longer active',
                              style: T.mono(11, w: FontWeight.w400, color: C.muted)),
                        ]),
                      ),
                      _SquareBtn(
                        icon: al['muted'] == true ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                        color: C.muted,
                        onTap: () => a.toggleMute(asS(al['id'])),
                      ),
                      const SizedBox(width: 6),
                      _SquareBtn(icon: Icons.close, color: C.red, onTap: () => a.remove(asS(al['id']))),
                    ]),
                  ),
                ),
              ),
          const SectionTitle('Recently triggered'),
          Panel(
            child: a.triggers.isEmpty
                ? const EmptyState(Icons.sensors, 'Nothing triggered yet')
                : Column(children: [
                    for (final t in a.triggers.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 7, height: 7,
                            decoration: BoxDecoration(color: _kindColor(asS(t['kind'])), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(asS(t['msg']), style: T.body(12)),
                              Text(fmtDateTime(t['ts']), style: T.mono(10, w: FontWeight.w400, color: C.dim)),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 6),
          Text('Alerts are checked while the app is open.', textAlign: TextAlign.center, style: T.body(11, color: C.dim)),
          const SizedBox(height: 70),
        ],
      ),
      Positioned(
        right: 16, bottom: 16,
        child: GestureDetector(
          onTap: () {
            if (!pro && a.activeCount >= kFreeAlertLimit) {
              showBanner('Free plan limit', 'Free accounts can keep $kFreeAlertLimit active alerts. Pro is unlimited.');
              return;
            }
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: C.panel,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
              builder: (_) => _NewAlertSheet(pro: pro),
            );
          },
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: C.gold,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: C.gold.withAlpha(90), blurRadius: 22, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.add, color: C.onGold, size: 26),
          ),
        ),
      ),
    ]);
  }
}

class _SquareBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SquareBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: color == C.red ? C.redBg : C.panelHi,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color == C.red ? C.red.withAlpha(80) : C.border)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _NewAlertSheet extends StatefulWidget {
  final bool pro;
  const _NewAlertSheet({required this.pro});
  @override
  State<_NewAlertSheet> createState() => _NewAlertSheetState();
}

class _NewAlertSheetState extends State<_NewAlertSheet> {
  final _value = TextEditingController();
  String _type = 'price', _side = 'CE', _cond = 'above', _signalCond = 'ANY';
  int? _strike;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _setType(String t) {
    if ((t == 'signal' || t == 'trap') && !widget.pro) {
      setState(() => _error = 'Signal and trap alerts are a Pro feature.');
      return;
    }
    setState(() {
      _type = t;
      _error = null;
    });
  }

  void _create() {
    final alert = <String, dynamic>{'type': _type};
    if (_type == 'price' || _type == 'oi') {
      final v = double.tryParse(_value.text.trim());
      if (v == null || _strike == null) {
        setState(() => _error = 'Pick a strike and enter a trigger value.');
        return;
      }
      alert.addAll({'strike': _strike, 'side': _side, 'cond': _cond, 'value': v});
    } else if (_type == 'signal') {
      alert['signalCond'] = _signalCond;
    }
    context.read<AlertsState>().add(alert);
    Navigator.pop(context);
    showBanner('Alert created', AlertsState.label(alert));
  }

  Widget _typeOpt(String t, String title, String desc, {bool proOnly = false}) {
    final on = _type == t;
    return GestureDetector(
      onTap: () => _setType(t),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: on ? C.goldBg : C.panelHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? C.gold : C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(title, style: T.body(12.5, w: FontWeight.w700))),
            if (proOnly) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(5)),
                child: Text('PRO', style: T.body(8.5, w: FontWeight.w700, color: C.onGold)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Text(desc, style: T.body(10, color: C.muted, height: 1.35)),
        ]),
      ),
    );
  }

  Widget _toggle(List<(String, String)> opts, String current, ValueChanged<String> onPick) {
    return Row(children: [
      for (var i = 0; i < opts.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onPick(opts[i].$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current == opts[i].$1 ? C.goldBg : C.panelHi,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: current == opts[i].$1 ? C.gold : C.border),
              ),
              child: Text(opts[i].$2,
                  style: T.body(12.5, w: FontWeight.w600, color: current == opts[i].$1 ? C.gold : C.muted)),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 7),
        child: Text(t.toUpperCase(), style: T.label(C.muted)),
      );

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MarketState>();
    _strike ??= m.atm == 0 ? null : m.atm;
    final strikeFields = _type == 'price' || _type == 'oi';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('New alert', style: T.disp(18)),
            _label('Alert type'),
            Grid2(children: [
              _typeOpt('price', '💰 Price', 'Strike LTP crosses a value'),
              _typeOpt('oi', '📊 OI change', 'Open-interest shift on a strike'),
              _typeOpt('signal', '⚡ Golden signal', 'When a buy signal fires', proOnly: true),
              _typeOpt('trap', '🪤 Trap detected', 'Bullish / bearish trap near spot', proOnly: true),
            ]),
            if (strikeFields) ...[
              _label('Strike'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: C.panelHi, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: m.rowFor(_strike) == null ? null : _strike,
                    isExpanded: true,
                    dropdownColor: C.panelHi,
                    style: T.mono(13.5),
                    items: [
                      for (final r in m.chain)
                        DropdownMenuItem(
                          value: asI(r['strike']),
                          child: Text('${asI(r['strike'])}${asI(r['strike']) == m.atm ? '  (ATM)' : ''}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _strike = v),
                  ),
                ),
              ),
              _label('Side'),
              _toggle(const [('CE', 'CALL (CE)'), ('PE', 'PUT (PE)')], _side, (v) => setState(() => _side = v)),
              _label(_type == 'oi' ? 'OI condition' : 'Price condition'),
              _toggle(const [('above', 'Above'), ('below', 'Below')], _cond, (v) => setState(() => _cond = v)),
              _label(_type == 'oi' ? 'Trigger value (OI change)' : 'Trigger value (₹)'),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: T.mono(13.5),
                decoration: const InputDecoration(hintText: 'e.g. 120.00', isDense: true),
              ),
            ],
            if (_type == 'signal') ...[
              _label('Trigger on'),
              _toggle(const [('ANY', 'Any buy signal'), ('BUY_CALL', 'Buy call only')], _signalCond,
                  (v) => setState(() => _signalCond = v)),
            ],
            if (_type == 'trap')
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text("You'll be alerted the moment a bullish or bearish OI trap is detected near spot.",
                    style: T.body(12.5, color: C.muted, height: 1.5)),
              ),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: T.body(12.5, color: C.red))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: T.disp(14, color: C.muted)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _create,
                  child: const Text('Create alert'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
