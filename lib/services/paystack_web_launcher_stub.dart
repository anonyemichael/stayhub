// Stub implementation — used on mobile/non-web platforms.
// The real implementation is in paystack_web_launcher.dart.

Future<String?> launchPaystackInline({
  required String accessCode,
  required String authUrl,
  required void Function(String reference) onSuccess,
  required void Function() onClose,
}) {
  // No-op on mobile — mobile uses WebView instead.
  return Future.value(null);
}
