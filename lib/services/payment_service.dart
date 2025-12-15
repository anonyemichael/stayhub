import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';

class PaymentService {
  // ⚠️ REPLACE WITH YOUR PUBLIC KEY FROM PAYSTACK DASHBOARD
  final String _publicKey = "pk_test_b1cd4cb2e4b10627b8f662d1af08e1e04d36f6af";
  
  // ⚠️ REPLACE WITH YOUR SECRET KEY FROM PAYSTACK DASHBOARD (Required for flutter_paystack_plus on mobile)
  final String _secretKey = "sk_test_dd38d5d75c78c6aa726c36363469a0b1e086b7f3"; 

  void initialize() {
    // Initialization handled in openPaystackPopup
  }

  Future<String?> chargeCard({
    required BuildContext context,
    required double amount, // In GHS
    required String email,
    required String reference,
  }) async {
    final completer = Completer<String?>();

    try {
      // Paystack takes amount in kobo/pesewas (multiply by 100)
      final String amountInPesewas = (amount * 100).toInt().toString();
      
      await FlutterPaystackPlus.openPaystackPopup(
        publicKey: _publicKey,
        context: context,
        secretKey: _secretKey,
        currency: 'GHS',
        customerEmail: email,
        amount: amountInPesewas,
        reference: reference,
        callBackUrl: "https://stayhub.app/payment-callback", // Valid URL scheme required by some SDKs
        onSuccess: () {
          if (!completer.isCompleted) completer.complete(reference);
        },
        onClosed: () {
          if (!completer.isCompleted) completer.complete(null);
        },
      );
    } catch (e) {
      debugPrint("Payment Error: $e");
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }
}
