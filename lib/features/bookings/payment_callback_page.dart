import 'package:flutter/material.dart';
import 'dart:async';
import 'package:stayhub/features/bookings/bookings_page.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:stayhub/core/html_stub.dart' if (dart.library.html) 'dart:html' as html;

class PaymentCallbackPage extends StatefulWidget {
  final String? reference;
  final String? bookingId;
  final String? userId;
  final double? amount;

  const PaymentCallbackPage({
    super.key,
    this.reference,
    this.bookingId,
    this.userId,
    this.amount,
  });

  @override
  State<PaymentCallbackPage> createState() => _PaymentCallbackPageState();
}

class _PaymentCallbackPageState extends State<PaymentCallbackPage> {
  bool _isVerifying = true;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      final queryParams = Uri.base.queryParameters;
      final reference = widget.reference ?? queryParams['reference'] ?? queryParams['trxref'];
      
      // We can still try to get these from the URL as fallbacks if Paystack's metadata is missing
      final bookingId = widget.bookingId ?? queryParams['bookingId'];
      final userId = widget.userId ?? queryParams['userId'];
      final amountStr = queryParams['amount'];
      final double? amount = widget.amount ?? (amountStr != null ? double.tryParse(amountStr) : null);

      if (reference != null) {
        // Delegate verification entirely to the service, which will use Paystack's metadata
        final success = await PaymentService().verifyAndSync(
            reference, 
            bookingId: bookingId,
        );
        
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _isSuccess = success;
            if (!success) _errorMessage = "Verification failed. Please check your bookings page.";
          });
        }
      } else {
        // If there's no reference at all, we can't do anything
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _isSuccess = false;
            _errorMessage = "Invalid payment callback. No transaction reference found.";
          });
        }
      }

      if (_isSuccess) {
        // If we're on Web and likely in a popup or iframe, notify the parent
        if (kIsWeb) {
          // ignore: undefined_prefixed_name
          html.window.parent?.postMessage('PAYMENT_SUCCESS', '*');
        }

        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            // For Web, if we opened in _blank or iframe, the original tab is already updating.
            // We can just stay here or close.
            if (!kIsWeb) {
               _returnToApp();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isSuccess = false;
          _errorMessage = "An error occurred during verification.";
        });
      }
    }
  }

  void _returnToApp() {
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => const BookingsPage()),
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isVerifying) ...[
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  "Verifying Payment...",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ] else if (_isSuccess) ...[
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 100),
                const SizedBox(height: 24),
                const Text(
                  "Payment Successful! ✅",
                  style: TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Your transaction has been verified. You can now close this window and return to the main app tab.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    if (kIsWeb) {
                       // On Web, try to close the window
                       _returnToApp(); // Fallback if close doesn't work
                    } else {
                       _returnToApp();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(kIsWeb ? "Return to Bookings" : "Back to My Bookings"),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                       // This is a common way to suggest closing on web
                       _returnToApp(); 
                    },
                    child: const Text("Done", style: TextStyle(color: Colors.blue)),
                  )
                ]
              ] else ...[
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 100),
                const SizedBox(height: 24),
                const Text(
                  "Payment Unverified",
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? "We couldn't verify your payment instantly. Please check your bookings page in a moment.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _returnToApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_isSuccess ? "RETURN TO APP NOW" : "CHECK BOOKINGS", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
