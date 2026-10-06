import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'main.dart';

/// Opens the phone's email app with a message to support already started.
/// If the phone has no email app, the address is copied so the user can paste it.
Future<void> contactSupport({String? accountEmail, String topic = 'Support request'}) async {
  final body = [
    'Hi PaperTradeLab team,',
    '',
    '',
    '',
    '— Please keep the lines below, they help us find your account —',
    if (accountEmail != null && accountEmail.isNotEmpty) 'Account: $accountEmail',
    'App: ${AppConfig.appName} ${defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android'} (${AppConfig.store})',
  ].join('\n');

  // Built by hand: Uri(queryParameters:) would turn spaces into "+", which
  // many email apps show literally.
  final uri = Uri.parse('mailto:${AppConfig.supportEmail}'
      '?subject=${Uri.encodeComponent('$topic — ${AppConfig.appName}')}'
      '&body=${Uri.encodeComponent(body)}');

  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    await Clipboard.setData(const ClipboardData(text: AppConfig.supportEmail));
    showBanner('Email address copied', 'No email app found. Write to ${AppConfig.supportEmail}');
  }
}
