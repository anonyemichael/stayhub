@JS()
library paystack;

import 'package:js/js.dart';
import 'dart:html' as html;

@JS('PaystackPop')
class PaystackPop {
  external PaystackPop();
  /// Resumes a transaction using an access code.
  /// [options] can contain onSuccess and onClose callbacks.
  external void resumeTransaction(String accessCode, [PaystackOptions? options]);
}

@JS()
@anonymous
class PaystackOptions {
  external factory PaystackOptions({
    Function(dynamic response)? onSuccess,
    Function()? onClose,
  });
  external Function(dynamic response)? get onSuccess;
  external Function()? get onClose;
}

/// Helper to trigger the Paystack modal and handle results without redirects.
void openPaymentPopup({
  required String url,
  required Function(String reference) onSuccess,
  required Function() onClose,
}) {
  try {
    final uri = Uri.parse(url);
    final accessCode = uri.pathSegments.last;

    final paystack = PaystackPop();
    
    paystack.resumeTransaction(
      accessCode, 
      PaystackOptions(
        onSuccess: allowInterop((response) {
          // Paystack v2 response contains reference
          // In some cases response is a Map, in others a JS object.
          // Using a more robust way to extract reference
          String? ref;
          try {
            ref = (response as dynamic).reference?.toString();
          } catch (_) {
            try {
               ref = response['reference']?.toString();
            } catch (_) {}
          }
          
          if (ref != null) {
            onSuccess(ref);
          }
        }),
        onClose: allowInterop(() {
          onClose();
        }),
      ),
    );
  } catch (e) {
    // Fallback to window.open if JS SDK fails
    html.window.open(url, 'Paystack Payment', 'width=600,height=800,menubar=no');
  }
}

/// Helper to forcefully redirect the current browser tab to Paystack.
/// This avoids popup blockers because it navigates the top-level window.
void redirectToCheckout(String url) {
  // Using location.replace replaces the current history entry.
  // This is often more stable for top-level redirects as it doesn't 
  // add a "broken" half-state to the browser history.
  html.window.location.replace(url);
}
