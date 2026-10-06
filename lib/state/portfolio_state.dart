import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../format.dart';

/// The user's own paper account. Polls every 2s only while the Trade tab is
/// visible and the app is in the foreground.
class PortfolioState extends ChangeNotifier {
  final Api api;
  PortfolioState(this.api);

  Map<String, dynamic> data = {};
  String? error;
  VoidCallback? onAuthLost;

  Timer? _timer;
  bool _busy = false;
  bool _running = false;

  bool get hasData => data.isNotEmpty;
  bool get marketOpen => data['market_open'] == true;
  double get balance => asD(data['balance']) ?? 0;
  int get lotSize => asI(data['lot_size'], 65);
  List<Map<String, dynamic>> get positions => asList(data['positions']).map(asMap).toList();
  List<Map<String, dynamic>> get recentTrades => asList(data['recent_trades']).map(asMap).toList();

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
  }

  /// Use the portfolio snapshot that buy / sell / reset responses already carry.
  void apply(Map<String, dynamic> portfolio) {
    if (portfolio.isEmpty) return;
    data = portfolio;
    error = null;
    notifyListeners();
  }

  Future<void> refreshNow() => _fetch();

  Future<void> _tick() async {
    await _fetch();
    _timer?.cancel();
    if (!_running) return;
    final secs = (hasData && !marketOpen) ? 30 : (positions.isEmpty ? 10 : 5);
    _timer = Timer(Duration(seconds: secs), _tick);
  }

  Future<void> _fetch() async {
    if (_busy) return;
    _busy = true;
    try {
      data = await api.portfolio();
      error = null;
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
