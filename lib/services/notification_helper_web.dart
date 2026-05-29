import 'package:flutter/foundation.dart';
import 'dart:js' as js;

void showWebNotification(String title, String body) {
  if (!kIsWeb) return;

  // Check if browser supports notifications
  final bool hasSupport = js.context.hasProperty('Notification');
  if (!hasSupport) {
    debugPrint("Web: Browser does not support Notification API");
    return;
  }

  // Check permission
  final String permission = js.context['Notification']['permission'];
  if (permission == 'granted') {
    _triggerJsNotification(title, body);
  } else if (permission != 'denied') {
    // Request permission again if not denied
    js.context['Notification'].callMethod('requestPermission').then((status) {
      if (status == 'granted') {
        _triggerJsNotification(title, body);
      }
    });
  }
}

void _triggerJsNotification(String title, String body) {
  try {
    js.context.callMethod('eval', [
      "new Notification('$title', { body: '$body', icon: '/app/icons/Icon-192.png' });"
    ]);
  } catch (e) {
    debugPrint("JS Notification Error: $e");
  }
}
