import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../format.dart';
import 'market_state.dart';

const int kFreeAlertLimit = 2;

/// Smart alerts, stored on this phone. Checked on every market tick while the
/// app is open: price / OI-change on a strike, golden signal (Pro), OI trap (Pro).
class AlertsState extends ChangeNotifier {
  List<Map<String, dynamic>> alerts = [];
  List<Map<String, dynamic>> triggers = [];
  int unread = 0;
  void Function(String title, String body)? onFire;

  File? _file;
  DateTime _lastTrap = DateTime.fromMillisecondsSinceEpoch(0);

  int get activeCount => alerts.where((a) => a['active'] == true).length;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/alerts_v1.json');
      if (await _file!.exists()) {
        final d = asMap(jsonDecode(await _file!.readAsString()));
        alerts = asList(d['alerts']).map(asMap).toList();
        triggers = asList(d['triggers']).map(asMap).toList();
      }
    } catch (_) {/* start empty */}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode({'alerts': alerts, 'triggers': triggers.take(50).toList()}));
    } catch (_) {}
  }

  void add(Map<String, dynamic> alert) {
    alerts.add({
      ...alert,
      'id': 'a${DateTime.now().millisecondsSinceEpoch}',
      'active': true,
      'muted': false,
    });
    _save();
    notifyListeners();
  }

  void remove(String id) {
    alerts.removeWhere((a) => a['id'] == id);
    _save();
    notifyListeners();
  }

  void toggleMute(String id) {
    for (final a in alerts) {
      if (a['id'] == id) a['muted'] = !(a['muted'] == true);
    }
    _save();
    notifyListeners();
  }

  void clearUnread() {
    if (unread == 0) return;
    unread = 0;
    notifyListeners();
  }

  static String label(Map<String, dynamic> a) {
    switch (asS(a['type'])) {
      case 'price':
        return 'NIFTY ${a['strike']} ${a['side']} price';
      case 'oi':
        return 'NIFTY ${a['strike']} ${a['side']} OI change';
      case 'signal':
        return 'Golden Signal — ${a['signalCond'] == 'BUY_CALL' ? 'buy call only' : 'any buy signal'}';
      case 'trap':
        return 'Any OI trap detected';
    }
    return 'Alert';
  }

  static String sub(Map<String, dynamic> a) {
    switch (asS(a['type'])) {
      case 'price':
        return 'When LTP goes ${a['cond']} ₹${fmtNum(asD(a['value']))}';
      case 'oi':
        return 'When OI change goes ${a['cond']} ${fmtNum(asD(a['value']), dp: 0)}';
      case 'signal':
      case 'trap':
        return 'Live · Pro feed';
    }
    return '';
  }

  void _fire(Map<String, dynamic> a, String msg, String kind, {bool deactivate = true}) {
    if (deactivate) a['active'] = false;
    if (a['muted'] == true) return;
    triggers.insert(0, {'msg': msg, 'ts': DateTime.now().toUtc().toIso8601String(), 'kind': kind});
    unread++;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
    onFire?.call('🔔 Alert', msg);
  }

  /// Called by MarketState after every successful refresh.
  void evaluate(MarketState m) {
    var changed = false;
    for (final a in alerts) {
      if (a['active'] != true) continue;
      final type = asS(a['type']);
      if (type == 'price' || type == 'oi') {
        final leg = m.legFor(asI(a['strike']), asS(a['side'], 'CE'));
        if (leg == null) continue;
        final cur = asD(type == 'price' ? leg['ltp'] : leg['oi_delta']);
        final target = asD(a['value']);
        if (cur == null || target == null) continue;
        final hit = a['cond'] == 'above' ? cur >= target : cur <= target;
        if (hit) {
          _fire(a, 'NIFTY ${a['strike']} ${a['side']} ${type == 'price' ? 'LTP' : 'ΔOI'} ${a['cond']} '
              '${fmtNum(target, dp: type == 'price' ? 2 : 0)} (now ${fmtNum(cur, dp: type == 'price' ? 2 : 0)})',
              type);
          changed = true;
        }
      } else if (type == 'signal' && m.subscribed) {
        final g = m.golden;
        if (g == null || g['entry_ready'] != true) continue;
        final sig = asS(g['signal']);
        final match = a['signalCond'] == 'BUY_CALL' ? sig == 'BUY_CALL' : (sig == 'BUY_CALL' || sig == 'BUY_PUT');
        if (match) {
          _fire(a, 'Golden Signal: ${sig.replaceAll('_', ' ')} · strike ${g['strike']} · ${g['strength']}% strength',
              sig == 'BUY_CALL' ? 'bull' : 'bear');
          changed = true;
        }
      } else if (type == 'trap' && m.subscribed && m.traps.isNotEmpty) {
        if (DateTime.now().difference(_lastTrap) < const Duration(seconds: 60)) continue;
        _lastTrap = DateTime.now();
        final t = m.traps.first;
        _fire(a, '${t['side'] == 'bull' ? 'Bullish' : 'Bearish'} trap detected at strike ${t['strike']}',
            t['side'] == 'bull' ? 'bull' : 'bear', deactivate: false);
        changed = true;
      }
    }
    if (changed) {
      _save();
      notifyListeners();
    }
  }
}
