void openPaymentPopup({
  required String url,
  required Function(String reference) onSuccess,
  required Function() onClose,
}) {
  throw UnsupportedError('Cannot open popup on this platform');
}

void redirectToCheckout(String url) {
  throw UnsupportedError('Cannot redirect on this platform');
}
