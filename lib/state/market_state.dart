import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../format.dart';

/// Everything the home screen shows: spot, chain, Pro analytics, golden signal.
/// One request (/api/m/market) every 2s while the market is open, 15s when closed.
/// Also owns the user's current strike / side / lots selection so the Chain tab
/// and the Trade tab stay in sync.
class MarketState extends ChangeNotifier {
  final Api api;
  MarketState(this.api);

  // feed
  bool hasData = false;
  bool marketOpen = false;
  bool subscribed = false;
  double? spot, change, changePct;
  int atm = 0;
  int lotSize = 65;
  String expiry = '';
  List<Map<String, dynamic>> chain = [];
  Map<String, dynamic>? pro;
  Map<String, dynamic>? golden;
  final List<double> spotHistory = [];
  DateTime? lastOk;
  String? error;

  // slower Pro extras (only fetched while the Signals tab is open)
  List<Map<String, dynamic>> traps = [];
  Map<String, dynamic> slLevels = {}, slRisk = {}, overall = {}, participant = {};

  // selection
  int? selectedStrike;
  String side = 'CE';
  int lots = 1;

  VoidCallback? onAuthLost;
  void Function(MarketState m)? onTick; // alerts engine hooks in here

  Timer? _timer, _extrasTimer;
  bool _busy = false, _running = false, _signalsVisible = false;
  DateTime? _participantAt;

  Map<String, dynamic>? rowFor(int? strike) {
    if (strike == null) return null;
    for (final r in chain) {
      if (asI(r['strike']) == strike) return r;
    }
    return null;
  }

  Map<String, dynamic>? legFor(int? strike, String side) {
    final row = rowFor(strike);
    if (row == null) return null;
    final leg = asMap(row[side.toLowerCase()]);
    return leg.isEmpty ? null : leg;
  }

  Map<String, dynamic>? get selectedLeg => legFor(selectedStrike, side);
  double? get selectedLtp => asD(selectedLeg?['ltp']);

  void selectStrike(int strike) {
    selectedStrike = strike;
    notifyListeners();
  }

  void setSide(String s) {
    side = s;
    notifyListeners();
  }

  void stepLots(int delta) {
    lots = (lots + delta).clamp(1, 50);
    notifyListeners();
  }

  void start() {
    if (_running) return;
    _running = true;
    _tick();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _extrasTimer?.cancel();
  }

  void reset() {
    stop();
    hasData = false;
    chain = [];
    pro = null;
    golden = null;
    spotHistory.clear();
    selectedStrike = null;
    error = null;
  }

  Future<void> refreshNow() => _fetch();

  void setSignalsVisible(bool visible) {
    _signalsVisible = visible;
    _extrasTimer?.cancel();
    if (visible) {
      _loadExtras();
      _extrasTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadExtras());
    }
  }

  Future<void> _tick() async {
    await _fetch();
    _timer?.cancel();
    if (!_running) return;
    _timer = Timer(Duration(seconds: (hasData && !marketOpen) ? 15 : 2), _tick);
  }

  Future<void> _fetch() async {
    if (_busy) return;
    _busy = true;
    try {
      final d = await api.market();
      marketOpen = d['market_open'] == true;
      subscribed = d['subscribed'] == true;
      spot = asD(d['spot']);
      change = asD(d['change']);
      changePct = asD(d['change_pct']);
      atm = asI(d['atm']);
      lotSize = asI(d['lot_size'], 65);
      expiry = asS(d['expiry']);
      final rows = asList(d['chain']).map(asMap).toList();
      if (rows.isNotEmpty) {
        rows.sort((a, b) => asI(a['strike']).compareTo(asI(b['strike'])));
        chain = rows;
      }
      pro = d['pro'] == null ? null : asMap(d['pro']);
      golden = d['golden'] == null ? null : asMap(d['golden']);
      if (selectedStrike == null && atm > 0) selectedStrike = atm;
      final s = spot;
      if (s != null && s > 0) {
        spotHistory.add(s);
        if (spotHistory.length > 150) spotHistory.removeAt(0);
      }
      hasData = true;
      error = null;
      lastOk = DateTime.now();
      onTick?.call(this);
    } on ApiException catch (e) {
      if (e.isAuth) {
        stop();
        onAuthLost?.call();
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'Connection problem.';
    } finally {
      _busy = false;
    }
    notifyListeners();
  }

  Future<void> _loadExtras() async {
    if (!subscribed || !_signalsVisible) return;
    Future<void> grab(Future<Map<String, dynamic>> f, void Function(Map<String, dynamic>) put) async {
      try {
        final d = await f;
        if (d['error'] == null) put(d);
      } catch (_) {/* optional data — keep the last good copy */}
    }

    await Future.wait([
      grab(api.traps(), (d) {
        traps = [
          for (final t in asList(d['bullish'])) {...asMap(t), 'side': 'bull'},
          for (final t in asList(d['bearish'])) {...asMap(t), 'side': 'bear'},
        ];
      }),
      grab(api.slLevels(), (d) => slLevels = d),
      grab(api.slRiskBulk(), (d) => slRisk = d),
      grab(api.overallDirection(), (d) => overall = d),
    ]);
    final last = _participantAt;
    if (last == null || DateTime.now().difference(last) > const Duration(minutes: 10)) {
      await grab(api.participant(), (d) {
        participant = d;
        _participantAt = DateTime.now();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
