import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Push notifications are OFF until you fill this in.
///
/// Firebase console → Project settings → Your apps:
///   • Android app  (package   com.papertradelab.papertradelab) → values are the same as in google-services.json
///   • iOS app      (bundle ID com.papertradelab.papertradelab) → values are the same as in GoogleService-Info.plist
///     (API_KEY, GOOGLE_APP_ID, GCM_SENDER_ID, PROJECT_ID)
/// then set enabled = true.
///
/// iOS additionally needs an APNs key: Apple Developer → Keys → "+" → Apple Push Notifications service (APNs),
/// download the .p8 and upload it in Firebase → Project settings → Cloud Messaging → Apple app configuration.
/// Without it iPhones never receive a push (the app still works).
class FirebaseCfg {
  static const bool enabled = false;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID', // looks like 1:1234567890:android:abc123
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID', // looks like 1:1234567890:ios:abc123
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    iosBundleId: 'com.papertradelab.papertradelab',
  );

  /// The options for the platform the app is running on.
  static FirebaseOptions get options {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }
}
