import 'dart:io';

import 'package:flutter/services.dart';

import 'activity_log.dart';

/// Toggles Android FLAG_SECURE: hides app content from screenshots, screen
/// recording and the recent-apps thumbnail.
class SecureWindow {
  static const _channel = MethodChannel('uz.shellbox/window');

  static Future<void> apply(bool secure) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on PlatformException catch (e) {
      ActivityLog.instance.error('SECURITY', 'FLAG_SECURE: ${e.message}');
    }
  }
}
