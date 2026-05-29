import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Conditionally import the web JS launcher
import 'paystack_web_launcher_stub.dart'
    if (dart.library.html) 'paystack_web_launcher.dart' as ps;

// ─────────────────────────────────────────────────────────────────────────────
// PaymentSheet
// ─────────────────────────────────────────────────────────────────────────────
// On Web   → shows a "Launch Payment" button that fires Paystack Inline JS SDK
//            (no redirect, no new tab — exactly like Google Sign-In popup).
// On Mobile → embeds Paystack checkout inside a WebView within the sheet.
// Both     → listen to Firestore for the PAID status update.
// ─────────────────────────────────────────────────────────────────────────────

class PaymentSheet extends StatefulWidget {
  final String authUrl;
  final String accessCode;
  final String reference;
  final String bookingId;
  final double amount;

  const PaymentSheet._({
    required this.authUrl,
    required this.accessCode,
    required this.reference,
    required this.bookingId,
    required this.amount,
  });

  /// Show the payment sheet. Returns `true` when payment is confirmed.
  static Future<bool?> show(
    BuildContext context, {
    required String authUrl,
    required String accessCode,
    required String reference,
    required String bookingId,
    required double amount,
  }) {
    debugPrint('[PaymentSheet] Showing sheet for ref: $reference');
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet._(
        authUrl: authUrl,
        accessCode: accessCode,
        reference: reference,
        bookingId: bookingId,
        amount: amount,
      ),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

// ─────────────────────────────────────────────────────────────────────────────

enum _Step { ready, paying, verifying, success, error }

class _PaymentSheetState extends State<PaymentSheet> {
  _Step _step = _Step.ready;
  String _errorMsg = "";
  WebViewController? _webCtrl;
  StreamSubscription? _bookingSub;
  bool _manualVerifyPending = false;
  bool _isLoadingWebView = true;
  double _loadProgress = 0;

  // ─── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startBookingListener();

    if (!kIsWeb) {
      // Mobile: start WebView immediately
      _setupWebView();
      setState(() => _step = _Step.paying);
    } else {
      // Web: auto-launch Paystack after first frame so the sheet is visible
      // (the JS bridge will hide Flutter canvas, open Paystack, then show it again)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _launchWebPayment();
      });
    }
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  // ─── Firestore listener ────────────────────────────────────────────────────

  void _startBookingListener() {
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;
      final status = (snap.data()?['status'] as String?)?.toUpperCase() ?? '';
      if (status == 'PAID' && _step != _Step.success) {
        setState(() => _step = _Step.success);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    });
  }

  // ─── Mobile WebView ────────────────────────────────────────────────────────

  void _setupWebView() {
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          debugPrint('[PaymentSheet] WebView PageStarted: $url');
          if (mounted) setState(() => _isLoadingWebView = true);
          _checkUrlForCompletion(url);
        },
        onPageFinished: (url) {
          debugPrint('[PaymentSheet] WebView PageFinished: $url');
          if (mounted) setState(() => _isLoadingWebView = false);
          _checkUrlForCompletion(url);
        },
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _loadProgress = progress / 100.0;
            });
          }
        },
        onWebResourceError: (error) {
          debugPrint('[PaymentSheet] WebView Error: ${error.description}');
          if (mounted) {
            setState(() {
              _isLoadingWebView = false;
              _errorMsg = "Page load failed: ${error.description}";
            });
          }
        },
        onNavigationRequest: (req) {
          final url = req.url.toLowerCase();
          debugPrint('[PaymentSheet] WebView NavigationRequest: $url');
          
          if (_checkUrlForCompletion(req.url)) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  bool _checkUrlForCompletion(String url) {
    final lowerUrl = url.toLowerCase();
    // Paystack redirects to callback URL on success
    if (lowerUrl.contains('payment-callback') ||
        lowerUrl.contains('status=success') ||
        lowerUrl.contains('trxref=')) {
      debugPrint('[PaymentSheet] Intercepted completion URL: $url');
      _onMobilePaymentComplete(url);
      return true;
    }
    return false;
  }

  void _onMobilePaymentComplete(String callbackUrl) {
    setState(() => _step = _Step.verifying);
    PaymentService()
        .verifyAndSync(widget.reference, bookingId: widget.bookingId)
        .then((ok) {
      if (!mounted) return;
      if (ok) {
        setState(() => _step = _Step.success);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _step = _Step.error;
          _errorMsg =
              "We couldn't confirm your payment instantly. Tap 'I've Paid' below to retry.";
        });
      }
    });
  }

  // ─── Web: launch Paystack inline JS popup ─────────────────────────────────

  void _launchWebPayment() {
    debugPrint('[PaymentSheet] Launching Web Payment...');
    setState(() => _step = _Step.paying);

    ps.launchPaystackInline(
      accessCode: widget.accessCode,
      authUrl: widget.authUrl,
      onSuccess: (ref) {
        if (!mounted) return;
        debugPrint('[PaymentSheet] JS onSuccess ref=$ref');
        setState(() => _step = _Step.verifying);
        PaymentService().verifyAndSync(ref, bookingId: widget.bookingId).then((ok) {
          if (!mounted) return;
          debugPrint('[PaymentSheet] Verification result: $ok');
          if (ok) {
            setState(() => _step = _Step.success);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          } else {
            // Firestore listener will also catch it if webhook fires
            setState(() {
              _step = _Step.error;
              _errorMsg = "Could not verify yet. Tap 'I've Paid' to check again.";
            });
          }
        });
      },
      onClose: () {
        debugPrint('[PaymentSheet] JS onClose called');
        if (!mounted) return;
        // User dismissed popup without paying — return to ready state
        setState(() => _step = _Step.ready);
      },
    );
  }

  // ─── Manual verify ─────────────────────────────────────────────────────────

  Future<void> _manualVerify() async {
    if (_manualVerifyPending) return;
    setState(() {
      _manualVerifyPending = true;
      _step = _Step.verifying;
    });
    final ok = await PaymentService()
        .verifyAndSync(widget.reference, bookingId: widget.bookingId);
    if (!mounted) return;
    setState(() => _manualVerifyPending = false);
    if (!ok) {
      setState(() {
        _step = _Step.error;
        _errorMsg =
            "Payment not confirmed yet. Please wait a moment and try again.";
      });
    }
    // If ok == true the Firestore listener will handle the success transition
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;

    // Mobile payment WebView uses full height
    final sheetHeight = (!kIsWeb && _step == _Step.paying)
        ? MediaQuery.of(context).size.height * 0.9
        : 500.0;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
          )
        ],
      ),
      child: Column(
        children: [
          _buildHandle(isDark),
          _buildHeader(isDark),
          Expanded(child: _buildBody(isDark)),
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00C3F7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PAYSTACK',
              style: TextStyle(
                color: Color(0xFF00C3F7),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          const Icon(Icons.lock_rounded, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text('Secure Payment',
              style: TextStyle(
                  color: Colors.green[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              padding: const EdgeInsets.all(6),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_step) {
      case _Step.ready:
        return _readyView(isDark);
      case _Step.paying:
        if (!kIsWeb && _webCtrl != null) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: WebViewWidget(controller: _webCtrl!),
              ),
              if (_isLoadingWebView)
                Container(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _loadProgress > 0 ? _loadProgress : null,
                          strokeWidth: 3,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading secure portal...',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }
        // Web: show a minimal waiting indicator while JS popup is open
        return _spinnerView('Paystack is open — complete your payment above', isDark);
      case _Step.verifying:
        return _spinnerView('Verifying payment…', isDark);
      case _Step.success:
        return _successView();
      case _Step.error:
        return _errorView(isDark);
    }
  }

  Widget _readyView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.payment_rounded,
                color: Colors.white, size: 38),
          ),
          const SizedBox(height: 24),
          Text(
            'Complete Your Booking',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'GHS ${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap below to open the secure payment portal',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: kIsWeb ? _launchWebPayment : null,  // on web: retry
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Pay Securely',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinnerView(String msg, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 24),
          Text(msg,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _successView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 48),
          ),
          const SizedBox(height: 24),
          const Text('Payment Confirmed!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.green)),
          const SizedBox(height: 10),
          Text('Redirecting to your receipt…',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _errorView(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.orange, size: 56),
          const SizedBox(height: 20),
          const Text('Payment Pending Confirmation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            _errorMsg.isNotEmpty
                ? _errorMsg
                : "If you completed payment, tap the button below.",
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _manualVerifyPending ? null : _manualVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _manualVerifyPending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("I've Completed Payment",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _step = _Step.ready),
              child: const Text('Try Again'),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    if (_step == _Step.success) return const SizedBox(height: 24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          if (_step == _Step.verifying || _step == _Step.paying)
            TextButton(
              onPressed: _manualVerify,
              child: const Text("I've already paid — verify now"),
            ),
          const SizedBox(height: 4),
          Text(
            'Ref: ${widget.reference}',
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white30 : Colors.grey[400],
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
