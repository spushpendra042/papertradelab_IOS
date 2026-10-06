import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import 'api.dart';
import 'firebase_options.dart';

/// Optional push notifications. Does nothing until FirebaseCfg.enabled = true.
class Push {
  static String? token;
  static bool _started = false;

  static Future<void> start(Api api, void Function(String title, String body) onForeground) async {
    if (!FirebaseCfg.enabled || _started) return;
    _started = true;
    try {
      await Firebase.initializeApp(options: FirebaseCfg.options);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      // iOS: an APNs token must exist before FCM can hand out a token. On a real
      // iPhone it normally arrives within a second; wait briefly, never fail.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      token = await fm.getToken();
      if (token != null) {
        await api.registerDevice(token!);
      }
      fm.onTokenRefresh.listen((t) {
        token = t;
        api.registerDevice(t).catchError((_) {});
      });
      // App in foreground: neither Android nor iOS shows a system notification
      // (iOS presentation options are left off on purpose), so we show our own banner.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground(n.title ?? '', n.body ?? '');
      });
    } catch (_) {
      _started = false; // try again next launch; the app works without push
    }
  }
}
