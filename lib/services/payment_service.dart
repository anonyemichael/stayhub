import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stayhub/core/api_config.dart';
import 'package:flutter/material.dart';
import 'package:stayhub/services/paystack_webview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentService {
  
  // ✅ SECURE IMPLEMENTATION 
  // Using Render Backend via ApiConfig
  final String _callbackUrl = "https://stayhub.app/payment-callback";

  // Persistent Client for connection reuse (Faster)
  static final http.Client _client = http.Client();
  
  void initialize() {
     prewarm();
  }

  /// Wake up functions to avoid cold starts
  Future<void> prewarm() async {
    try {
      _client.get(Uri.parse(ApiConfig.ping)).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Standard Charge
  Future<String?> chargeCard({
    required BuildContext context,
    required double amount, 
    required String email,
    required String reference,
  }) async {
     return _launchPayment(
       context: context, 
       amount: amount, 
       email: email, 
       reference: reference
     );
  }

  /// Split Payment Charge
  Future<String?> chargeCardWithSplit({
    required BuildContext context,
    required double amount,
    required String email,
    required String reference,
    required String subAccountCode, 
    double? transactionCharge, 
  }) async {
    return _launchPayment(
      context: context,
      amount: amount,
      email: email,
      reference: reference,
      subAccountCode: subAccountCode,
      transactionCharge: transactionCharge,
    );
  }

  /// Core logic to Init and Launch
  Future<String?> _launchPayment({
    required BuildContext context,
    required double amount,
    required String email,
    required String reference,
    String? subAccountCode,
    double? transactionCharge,
  }) async {
    // 1. Initialize Transaction via Backend
    // Show Loading? Usually handled by UI calling this.
    final authUrl = await _initializeTransactionApi(
      email: email,
      amount: amount,
      reference: reference,
      subAccountCode: subAccountCode,
      transactionCharge: transactionCharge,
    );

    if (authUrl == null) {
      if (context.mounted) _showErrorDialog(context, "Payment Server unreachable. This might be a temporary server delay. Please try again in a few moments.");
      return null;
    }

    // 2. Launch (Web vs Mobile)
    if (kIsWeb) {
       // Web: Launch in new tab
       if (await canLaunchUrl(Uri.parse(authUrl))) {
         await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
       } else {
         if (context.mounted) _showErrorDialog(context, "Could not open payment page.");
         return null;
       }

       // Web: Manual Verification Dialog
       if (!context.mounted) return null;
       final bool? verified = await showDialog<bool>(
         context: context,
         barrierDismissible: false,
         builder: (ctx) => AlertDialog(
           title: const Text("Completing Payment"),
           content: const Text("A payment page was opened in a new tab.\n\nDid you complete the payment?"),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(ctx, false),
               child: const Text("No, Cancel"),
             ),
             TextButton(
               onPressed: () => Navigator.pop(ctx, true),
               child: const Text("Yes, I Paid"),
             ),
           ],
         ),
       );

       if (verified == true) {
         final isSuccess = await _verifyTransaction(reference);
         if (isSuccess) return reference;
         if (context.mounted) _showErrorDialog(context, "Payment verification failed. Please check your bank.");
       }
       return null;

    } else {
      // Mobile: Use WebView
      if (!context.mounted) return null;
      
      final bool? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackWebView(
            authUrl: authUrl, 
            reference: reference, 
            callbackUrl: _callbackUrl
          ),
        ),
      );
  
      if (result == true) {
        final verified = await _verifyTransaction(reference);
        if (verified) {
           return reference;
        } else {
          if (context.mounted) _showErrorDialog(context, "Payment verification could not be confirmed automatically. Please contact support.");
        }
      }
      return null;
    }
  }

  Future<String?> _initializeTransactionApi({
    required String email,
    required double amount,
    required String reference,
    String? subAccountCode,
    double? transactionCharge,
  }) async {
    try {
      final int amountKobo = (amount * 100).toInt();
      final body = {
          "email": email,
          "amount": amountKobo,
          "reference": reference,
          "metadata": {
            "cancel_action": "https://stayhub.app/cancel",
             "custom_fields": [
                {
                    "display_name": "Send Receipt",
                    "variable_name": "send_receipt",
                    "value": "true"
                }
             ]
          }
      };
      
      if (subAccountCode != null) {
         body["subaccount"] = subAccountCode;
         if (transactionCharge != null) {
            body["transaction_charge"] = (transactionCharge * 100).toInt();
         }
      }

      final response = await _client.post(
        Uri.parse(ApiConfig.initializePayment), 
        headers: {
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30)); // INcreased to 30s to handle cold starts

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return data['data']['authorization_url'];
        }
      } else {
        debugPrint("Initialize Failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error Init: $e");
    }
    return null;
  }
  
  Future<bool> _verifyTransaction(String reference) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.verifyPayment}?reference=$reference'),
      ).timeout(const Duration(seconds: 5)); // FAST VERIFY (5s)
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true && data['data']['status'] == 'success';
      }
    } catch (e) {
      debugPrint("Verify Error: $e");
    }
    return false;
  }


  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Payment Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ===========================================================================
  // SUBACCOUNTS & BANKS 
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getBanks() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.getBanks)
      ).timeout(const Duration(seconds: 20)); // Longer timeout for large list
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching banks: $e");
    }
    return [];
  }

  Future<String> createSubAccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required String percentage, 
    required String email,
    String? contactName, 
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.createSubAccount), 
        headers: {
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "business_name": businessName,
          "settlement_bank": bankCode,
          "account_number": accountNumber,
          "percentage_charge": double.tryParse(percentage) ?? 0.0,
          "primary_contact_email": email,
          "primary_contact_name": contactName,
        })
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      
      // Check for both 200 and 201 (Created)
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == true) {
           return data['data']['subaccount_code'];
        }
      }
      
      final msg = data['message'] ?? "Unknown error";
      throw msg;

    } catch (e) {
       debugPrint("Error creating subaccount: $e");
       throw e.toString().replaceAll("Exception: ", "");
    }
  }
}
