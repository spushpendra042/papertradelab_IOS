import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../format.dart';

/// Polls /api/m/live. 2s while the market is open, 15s when closed, paused
/// completely while the app is in the background (saves battery and server load).
class LiveState extends ChangeNotifier {
  final Api api;
  LiveState(this.api);

  Map<String, dynamic> data = {};
  String? error;
  DateTime? lastOk;
  VoidCallback? onAuthLost;

  Timer? _timer;
  bool _busy = false;
  bool _running = false;

  bool get hasData => data.isNotEmpty;
  bool get marketOpen => data['market_open'] == true;
  bool get subscribed => data['subscribed'] == true;
  Map<String, dynamic> get market => asMap(data['market']);
  Map<String, dynamic> get meters => asMap(data['meters']);
  Map<String, dynamic>? get position => data['position'] == null ? null : asMap(data['position']);
  Map<String, dynamic> get today => asMap(data['today']);
  Map<String, dynamic>? get lastTrade => data['last_trade'] == null ? null : asMap(data['last_trade']);
  Map<String, dynamic> get rules => asMap(data['rules']);

  void start() {
    if (_running) return;
    _running = true;
    _tick();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    stop();
    data = {};
    error = null;
    lastOk = null;
  }

  Future<void> refreshNow() => _fetch();

  void _schedule() {
    _timer?.cancel();
    if (!_running) return;
    final secs = (hasData && !marketOpen) ? 15 : 2;
    _timer = Timer(Duration(seconds: secs), _tick);
  }

  Future<void> _tick() async {
    await _fetch();
    _schedule();
  }

  Future<void> _fetch() async {
    if (_busy) return;
    _busy = true;
    try {
      data = await api.live();
      error = null;
      lastOk = DateTime.now();
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

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
