import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:stayhub/services/paystack_webview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  
  // ⚠️ IMPLEMENTATION NOTE: 
  // We are performing direct API calls because Firebase Cloud Functions (Blaze plan) 
  // is not currently enabled. 
  // FOR PRODUCTION: It is highly recommended to move this logic to a backend 
  // to protect your Secret Key.
  
  static const String _secretKey = "sk_test_dd38d5d75c78c6aa726c36363469a0b1e086b7f3";
  final String _callbackUrl = "https://stayhub.app/payment-callback";

  void initialize() {}

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
    // 1. Initialize Transaction via Direct API
    final authUrl = await _initializeTransactionApi(
      email: email,
      amount: amount,
      reference: reference,
      subAccountCode: subAccountCode,
      transactionCharge: transactionCharge,
    );

    if (authUrl == null) {
      if (context.mounted) _showErrorDialog(context, "Failed to initialize payment. Check internet.");
      return null;
    }

    // 2. Launch WebView
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
        if (context.mounted) _showErrorDialog(context, "Payment verification failed.");
      }
    }
    
    return null;
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
          "currency": "GHS",
          "callback_url": _callbackUrl,
          "channels": ["card", "mobile_money", "ussd"],
      };
      
      if (subAccountCode != null) {
         body["subaccount"] = subAccountCode;
         body["bearer"] = "subaccount";
         if (transactionCharge != null) {
            body["transaction_charge"] = (transactionCharge * 100).toInt();
         }
      }

      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'), 
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );

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
      final response = await http.get(
        Uri.parse('https://api.paystack.co/transaction/verify/$reference'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
        },
      );
      
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
      // 1. Fetch Commercial Banks
      final banksResponse = await http.get(
        Uri.parse("https://api.paystack.co/bank?currency=GHS"),
         headers: {'Authorization': 'Bearer $_secretKey'}
      );

      // 2. Fetch Mobile Money
      final momoResponse = await http.get(
        Uri.parse("https://api.paystack.co/bank?currency=GHS&type=mobile_money"),
        headers: {'Authorization': 'Bearer $_secretKey'}
      );
      
      List<dynamic> allBanks = [];

      if (banksResponse.statusCode == 200) {
        final data = jsonDecode(banksResponse.body);
        if (data['status'] == true) {
           allBanks.addAll(data['data']);
        }
      }

      if (momoResponse.statusCode == 200) {
        final data = jsonDecode(momoResponse.body);
        if (data['status'] == true) {
          // Add only unique codes
          final existingCodes = allBanks.map((e) => e['code']).toSet();
          for (var item in data['data']) {
            if (!existingCodes.contains(item['code'])) {
              allBanks.add(item);
            }
          }
        }
      }

      // Sort Alphabetically
      allBanks.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      return List<Map<String, dynamic>>.from(allBanks);

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
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.paystack.co/subaccount'), 
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "business_name": businessName,
          "settlement_bank": bankCode,
          "account_number": accountNumber,
          "percentage_charge": double.tryParse(percentage) ?? 0.0,
        })
      );

      final data = jsonDecode(response.body);
      
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
