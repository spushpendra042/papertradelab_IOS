import 'package:flutter/foundation.dart';

import '../api.dart';
import '../format.dart';
import '../push.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState extends ChangeNotifier {
  final Api api;
  AuthState(this.api);

  AuthStatus status = AuthStatus.unknown;
  Map<String, dynamic> me = {};
  String? bootError;

  String get email => asS(me['email']);
  Map<String, dynamic> get sub => asMap(me['subscription']);
  bool get subscribed => sub['active'] == true;
  bool get isTrial => sub['is_trial'] == true;
  int get daysLeft => asI(sub['days_left']);
  int get lotSize => asI(me['lot_size'], 65);

  /// App start: if the saved session cookie is still valid we go straight in.
  Future<void> bootstrap() async {
    bootError = null;
    status = AuthStatus.unknown;
    notifyListeners();
    try {
      me = await api.me();
      status = AuthStatus.signedIn;
    } on ApiException catch (e) {
      if (e.isAuth) {
        status = AuthStatus.signedOut;
      } else {
        bootError = e.message;
      }
    } catch (_) {
      bootError = 'Could not start. Please try again.';
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    me = await api.login(email, password);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> completeRegistration(String otp) async {
    me = await api.verifyOtp(otp);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      me = await api.me();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isAuth) await sessionLost();
    }
  }

  Future<void> logout() async {
    await api.logout(Push.token);
    me = {};
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Server said the session is no longer valid.
  Future<void> sessionLost() async {
    if (status == AuthStatus.signedOut) return;
    await api.clearSession();
    me = {};
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
