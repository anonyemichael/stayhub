void openPaymentPopup({
  required String url,
  required Function(String reference) onSuccess,
  required Function() onClose,
}) {
  // On mobile, the WebView is embedded directly in the modal.
  // This method is intentionally a no-op on mobile.
}

void redirectToCheckout(String url) {
  // On mobile, we use PaymentSheet instead of top-level redirects
}
