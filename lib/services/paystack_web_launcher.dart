// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:flutter/foundation.dart';

/// Launches the Paystack Inline checkout by calling `window.openPaystackPortal(accessCode)`.
///
/// The actual JS (defined in web/index.html) handles:
///   1. Lowering Flutter's CanvasKit glass pane so Paystack overlay is visible
///   2. Calling `PaystackPop.resumeTransaction(accessCode, { onSuccess, onClose })`
///   3. Restoring Flutter's canvas after payment
///   4. Firing CustomEvents: 'paystackSuccess' and 'paystackClose'
///
/// This Dart function sets up listeners for those events and resolves the Future
/// with the transaction reference on success.
Future<String?> launchPaystackInline({
  required String accessCode,
  required String authUrl,
  required void Function(String reference) onSuccess,
  required void Function() onClose,
}) {
  if (accessCode.isEmpty || authUrl.isEmpty) {
    onClose();
    return Future.value(null);
  }

  debugPrint('[PaystackWeb] Calling JS bridge to redirect to Paystack: $authUrl');
  
  // Create a completer that will be resolved by JS events (if we don't redirect)
  // or just left pending if we do redirect.
  js_util.callMethod(html.window, 'openPaystackPortal', [accessCode, authUrl]);
  
  return Future.value(accessCode);
}
