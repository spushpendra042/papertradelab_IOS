import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../main.dart';
import '../state/portfolio_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the buy ticket. Pass [strike] + [optionType] to pre-select (used by "Follow signal").
Future<void> showOrderTicket(BuildContext context, {int? strike, String? optionType, String? title}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    showDragHandle: true,
    builder: (_) => _OrderTicket(strike: strike, optionType: optionType, title: title),
  );
}

class _OrderTicket extends StatefulWidget {
  final int? strike;
  final String? optionType;
  final String? title;
  const _OrderTicket({this.strike, this.optionType, this.title});
  @override
  State<_OrderTicket> createState() => _OrderTicketState();
}

class _OrderTicketState extends State<_OrderTicket> {
  List<Map<String, dynamic>> _rows = [];
  int _lotSize = 65;
  int _maxLots = 50;
  bool _marketOpen = true;
  String _expiry = '';
  late String _type;
  int? _strike;
  int _lots = 1;
  bool _loading = true;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.optionType ?? 'CE';
    _strike = widget.strike;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<Api>().chain();
      if (!mounted) return;
      setState(() {
        _rows = asList(r['rows']).map(asMap).toList();
        _lotSize = asI(r['lot_size'], 65);
        _maxLots = asI(r['max_lots'], 50);
        _marketOpen = r['market_open'] == true;
        _expiry = asS(r['expiry']);
        _strike ??= asI(r['atm']);
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

  double? get _price {
    for (final r in _rows) {
      if (asI(r['strike']) == _strike) return asD(r[_type.toLowerCase()]);
    }
    return null;
  }

  Future<void> _buy() async {
    final strike = _strike;
    if (strike == null) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      final r = await context.read<Api>().buy(strike, _type, _lots);
      if (!mounted) return;
      context.read<PortfolioState>().apply(asMap(r['portfolio']));
      Navigator.of(context).pop();
      showBanner('Order filled', asS(r['message']));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<PortfolioState>().balance;
    final price = _price;
    final cost = price == null ? null : price * _lots * _lotSize;
    final tooCostly = cost != null && cost > balance;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 560),
        child: _loading
            ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(children: [
                      Expanded(
                        child: Text(widget.title ?? 'Buy option',
                            style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      if (_expiry.isNotEmpty) Pill('Expiry $_expiry', color: C.muted),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Expanded(child: _typeButton('CE', 'Call (CE) · bullish', C.green)),
                      const SizedBox(width: 10),
                      Expanded(child: _typeButton('PE', 'Put (PE) · bearish', C.red)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        final s = asI(r['strike']);
                        final p = asD(r[_type.toLowerCase()]);
                        final sel = s == _strike;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _placing ? null : () => setState(() => _strike = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: sel ? C.accent.withAlpha(40) : null,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? C.accent : Colors.transparent),
                            ),
                            child: Row(children: [
                              Text('$s', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(width: 8),
                              if (r['is_atm'] == true) Pill('ATM', color: C.amber),
                              const Spacer(),
                              Text(p == null ? '—' : '₹${fmtNum(p)}',
                                  style: TextStyle(color: p == null ? C.muted : C.text, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const Text('Lots', style: TextStyle(color: C.muted)),
                        const Spacer(),
                        IconButton(
                            onPressed: (_lots > 1 && !_placing) ? () => setState(() => _lots--) : null,
                            icon: const Icon(Icons.remove_circle_outline)),
                        SizedBox(
                            width: 40,
                            child: Text('$_lots',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800))),
                        IconButton(
                            onPressed: (_lots < _maxLots && !_placing) ? () => setState(() => _lots++) : null,
                            icon: const Icon(Icons.add_circle_outline)),
                      ]),
                      Row(children: [
                        Expanded(
                          child: Text('${_lots * _lotSize} qty · cost ${fmtInr(cost)}',
                              style: TextStyle(color: tooCostly ? C.red : C.text, fontWeight: FontWeight.w600)),
                        ),
                        Text('Balance ${fmtInr(balance)}', style: const TextStyle(color: C.muted, fontSize: 12)),
                      ]),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_error!, style: const TextStyle(color: C.red)),
                        ),
                      if (!_marketOpen)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text('Market is closed. Orders work 09:15–15:30 IST.',
                              style: TextStyle(color: C.amber)),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: C.green),
                        onPressed: (_placing || price == null || tooCostly || !_marketOpen || _strike == null)
                            ? null
                            : _buy,
                        child: _placing
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : Text(price == null
                                ? 'Price unavailable'
                                : 'Buy NIFTY ${_strike ?? ''} $_type @ ₹${fmtNum(price)}'),
                      ),
                      const SizedBox(height: 6),
                      const Text('Paper trade — virtual money, filled at the live option price.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 11)),
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _typeButton(String type, String label, Color color) {
    final sel = _type == type;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: sel ? color : C.muted,
        backgroundColor: sel ? color.withAlpha(36) : null,
        side: BorderSide(color: sel ? color : C.border),
        minimumSize: const Size.fromHeight(44),
      ),
      onPressed: _placing ? null : () => setState(() => _type = type),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
