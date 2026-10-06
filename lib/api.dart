import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'format.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final bool network;
  ApiException(this.message, {this.status, this.network = false});
  bool get isAuth => status == 401 || status == 302;
  @override
  String toString() => message;
}

/// Thin client over the Flask backend. The login session lives in a persistent
/// cookie jar on disk, so the user logs in once and stays logged in.
class Api {
  final Dio _dio;
  final PersistCookieJar _jar;
  Api._(this._dio, this._jar);

  static Future<Api> create() async {
    final dir = await getApplicationSupportDirectory();
    final jar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/.session/'),
    );
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (_) => true,
      contentType: 'application/json',
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));
    dio.interceptors.add(CookieManager(jar));
    return Api._(dio, jar);
  }

  Future<Map<String, dynamic>> _req(String method, String path,
      {Map<String, dynamic>? body, Map<String, dynamic>? query}) async {
    Response<dynamic> r;
    try {
      r = await _dio.request<dynamic>(path,
          data: body, queryParameters: query, options: Options(method: method));
    } on DioException catch (e) {
      final timeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      throw ApiException(
          timeout ? 'Server is taking too long. Check your connection.' : 'No internet connection.',
          network: true);
    }
    final code = r.statusCode ?? 0;
    final data = asMap(r.data);
    if (code == 401 || code == 302) {
      throw ApiException(asS(data['message'], 'Please log in again.'), status: code);
    }
    if (code >= 400) {
      final msg = asS(data['message'], asS(data['error'], 'Something went wrong ($code).'));
      throw ApiException(msg, status: code);
    }
    if (r.data is! Map) {
      throw ApiException('Unexpected response from server.', status: code);
    }
    return data;
  }

  Future<void> clearSession() => _jar.deleteAll();

  // ── Auth ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> me() async => asMap((await _req('GET', '/api/m/me'))['me']);

  Future<Map<String, dynamic>> login(String email, String password) async =>
      asMap((await _req('POST', '/api/m/login', body: {'email': email, 'password': password}))['me']);

  Future<void> register(String email, String password) =>
      _req('POST', '/api/m/register', body: {'email': email, 'password': password});

  Future<Map<String, dynamic>> verifyOtp(String otp) async =>
      asMap((await _req('POST', '/api/m/verify-otp', body: {'otp': otp}))['me']);

  Future<void> logout(String? deviceToken) async {
    try {
      await _req('POST', '/api/m/logout', body: {'device_token': deviceToken});
    } catch (_) {/* logging out locally is what matters */}
    await clearSession();
  }

  Future<void> forgotPassword(String email) =>
      _req('POST', '/api/forgot-password', body: {'email': email});

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    final r = await _req('POST', '/api/reset-password-otp',
        body: {'email': email, 'otp': otp, 'new_password': newPassword});
    if (asS(r['status']) != 'ok') {
      throw ApiException(asS(r['message'], 'Could not reset password.'));
    }
  }

  Future<void> registerDevice(String token) => _req('POST', '/api/m/device', body: {'token': token});

  // ── Data ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> live() => _req('GET', '/api/m/live');

  Future<Map<String, dynamic>> performance() => _req('GET', '/api/m/performance');

  Future<Map<String, dynamic>> trades({int offset = 0, int limit = 30}) =>
      _req('GET', '/api/m/trades', query: {'offset': offset, 'limit': limit});

  // ── Home screen feed + the website's existing JSON endpoints ───────────
  Future<Map<String, dynamic>> market() => _req('GET', '/api/m/market');

  Future<Map<String, dynamic>> statement() {
    final now = DateTime.now();
    final end = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _req('GET', '/api/portfolio_statement', query: {'start': '2020-01-01', 'end': end});
  }

  Future<Map<String, dynamic>> tradeStats() => _req('GET', '/api/trade_stats');
  Future<Map<String, dynamic>> traps() => _req('GET', '/api/nifty_trap_signals');
  Future<Map<String, dynamic>> slLevels() => _req('GET', '/api/nifty_sl_levels');
  Future<Map<String, dynamic>> slRiskBulk() => _req('GET', '/api/sl_risk_bulk');
  Future<Map<String, dynamic>> overallDirection() => _req('GET', '/api/nifty_overall_direction');
  Future<Map<String, dynamic>> participant() => _req('GET', '/api/participant_summary');

  // ── Paper trading ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> portfolio() async =>
      asMap((await _req('GET', '/api/m/portfolio'))['portfolio']);

  Future<Map<String, dynamic>> chain() => _req('GET', '/api/m/chain');

  /// Returns {message, portfolio}.
  Future<Map<String, dynamic>> buy(int strike, String optionType, int lots) => _req('POST', '/api/m/trade',
      body: {'action': 'BUY', 'strike': strike, 'option_type': optionType, 'lots': lots});

  Future<Map<String, dynamic>> sell(int strike, String optionType) => _req('POST', '/api/m/trade',
      body: {'action': 'SELL', 'strike': strike, 'option_type': optionType});

  Future<Map<String, dynamic>> resetAccount(double amount) =>
      _req('POST', '/api/m/reset', body: {'amount': amount});

  // ── Payments (existing website endpoints) ───────────────────────────────
  Future<Map<String, dynamic>> plans() => _req('GET', '/api/m/plans');

  Future<Map<String, dynamic>> createOrder(String plan, String phone) =>
      _req('POST', '/create-order', body: {'plan': plan, 'phone': phone, 'source': 'app'});

  /// → "success" | "pending" | "failed" | "error" | "no_pending_order"
  Future<Map<String, dynamic>> verifyPayment(String orderId) =>
      _req('GET', '/verify-payment', query: {'order_id': orderId});
}
