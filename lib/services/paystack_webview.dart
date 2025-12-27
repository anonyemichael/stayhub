import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackWebView extends StatefulWidget {
  final String authUrl;
  final String reference;
  final String callbackUrl;

  const PaystackWebView({
    super.key,
    required this.authUrl,
    required this.reference,
    required this.callbackUrl,
  });

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
             setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
             setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url == widget.callbackUrl || 
                request.url.startsWith("https://stayhub.app/payment-callback")) { // Handle matches
              // Checks if transaction was successful 'standard' paystack redirect usually appends params ??
              // Actually we verify verification on backend usually, but for simple flow we assume redirect means done.
              Navigator.pop(context, true); // Success
              return NavigationDecision.prevent;
            }
            if (request.url.contains("cancel")) { // Sometimes they have cancel url
               Navigator.pop(context, false);
               return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paystack Checkout"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Check verification manually if closed? 
            // For now assume cancelled if closed manually.
            Navigator.pop(context, false);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
