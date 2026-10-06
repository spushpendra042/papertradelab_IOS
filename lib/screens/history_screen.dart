import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../format.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _page = 30;
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() => _loading = true);
    try {
      final r = await context.read<Api>().trades(offset: reset ? 0 : _items.length, limit: _page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(asList(r['trades']).map(asMap));
        _hasMore = r['has_more'] == true;
        _loadedOnce = true;
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.isAuth) {
        if (mounted) context.read<AuthState>().sessionLost();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetail(Map<String, dynamic> t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.panel,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${asS(t['side'])} · NIFTY ${asS(t['strike'])} ${asS(t['option_type'])}',
              style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(asS(t['exit_reason']), style: const TextStyle(color: C.muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 26, runSpacing: 14, children: [
            KeyValue('Entered', fmtDateTime(t['entry_time'])),
            KeyValue('Exited', fmtDateTime(t['exit_time'])),
            KeyValue('Held', fmtHold(t['entry_time'], t['exit_time'])),
            KeyValue('Entry spot', fmtNum(asD(t['entry_underlying']))),
            KeyValue('Exit spot', fmtNum(asD(t['exit_underlying']))),
            KeyValue('Result', '${fmtPts(asD(t['pnl_pts']))} pts', color: C.pnl(asD(t['pnl_pts']))),
            KeyValue('Option entry', '₹${fmtNum(asD(t['entry_ltp']))}'),
            KeyValue('Option exit', '₹${fmtNum(asD(t['exit_ltp']))}'),
            KeyValue('Paper P&L', fmtInr(asD(t['pnl_rs']), sign: true), color: C.pnl(asD(t['pnl_rs']))),
            KeyValue('Best during trade', '${fmtPts(asD(t['best_move']))} pts'),
            KeyValue('SL moved to entry', t['be_moved'] == true ? 'Yes' : 'No'),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      if (_error != null) return ErrorRetry(message: _error!, onRetry: () => _load(reset: true));
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth > 760 ? (c.maxWidth - 720) / 2 : 16.0;
        return ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 12, side, 24),
          itemCount: _items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
                child: Text('Signal history',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.text)),
              );
            }
            if (i == _items.length + 1) {
              if (_items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text('No closed signals yet.\nThey will appear here as soon as the first one closes.',
                      textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : Text(_hasMore ? '' : 'That is every signal so far.',
                          style: const TextStyle(color: C.muted, fontSize: 12)),
                ),
              );
            }
            final t = _items[i - 1];
            final pts = asD(t['pnl_pts']);
            final sell = t['side'] == 'SELL';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showDetail(t),
                child: Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Pill(sell ? 'SELL' : 'BUY', color: sell ? C.red : C.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('NIFTY ${asS(t['strike'])} ${asS(t['option_type'])}',
                            style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${fmtDateTime(t['entry_time'])} · held ${fmtHold(t['entry_time'], t['exit_time'])}',
                            style: const TextStyle(color: C.muted, fontSize: 12)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${fmtPts(pts)} pts',
                          style: TextStyle(color: C.pnl(pts), fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(fmtInr(asD(t['pnl_rs']), sign: true),
                          style: const TextStyle(color: C.muted, fontSize: 12)),
                    ]),
                  ]),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
