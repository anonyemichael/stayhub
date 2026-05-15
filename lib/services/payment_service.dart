import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:stayhub/services/payment_sheet.dart';
import 'package:stayhub/core/api_config.dart';

import 'package:stayhub/services/payment_helper_stub.dart'
    if (dart.library.html) 'package:stayhub/services/payment_helper_web.dart'
    if (dart.library.io) 'package:stayhub/services/payment_helper_mobile.dart' as payment_helper;

class PaymentService {
  static final http.Client _client = http.Client();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── CORE SECURE BOOKING FLOW ──────────────────────────────────────────────

  /// STEP 1: Prepare the booking by checking availability and creating a lock.
  /// returns lockId if successful.
  Future<String> prepareBooking({
    required String hostelId,
    required String roomId,
    required String checkIn,
    required String checkOut,
    String? idempotencyKey,
  }) async {
    debugPrint('[PaymentService] prepareBooking for Room: $roomId');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[PaymentService] No user logged in, aborting prepareBooking');
        throw 'You must be logged in to book a room.';
      }

      // Force-refresh the token to avoid expiry issues
      debugPrint('[PaymentService] Refreshing auth token...');
      await user.getIdToken(true);

      final result = await _functions.httpsCallable('prepareBooking').call({
        'hostelId': hostelId,
        'roomId': roomId,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'idempotencyKey': idempotencyKey,
      });

      final String status = result.data['status'];
      
      if (status == 'SUCCESS' || status == 'IDEMPOTENT_RESUME') {
        final String lockId = result.data['lockId'];
        debugPrint('[PaymentService] Lock Secured: $lockId');
        return lockId;
      }

      if (status == 'ERROR') {
        final String message = result.data['message'] ?? 'Unknown backend error';
        debugPrint('[PaymentService] Prepare failed with message: $message');
        throw message;
      }

      throw 'Failed to secure room. Status: $status';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] Prepare failed: ${e.code} - ${e.message}');
      throw e.message ?? 'Room is unavailable for these dates.';
    } catch (e) {
      debugPrint('[PaymentService] Unexpected prepare error: $e');
      if (e is String) rethrow;
      throw 'Could not start booking process. Please try again.';
    }
  }

  /// STEP 2: Get the payment portal URL using the lockId.
  Future<Map<String, dynamic>> getPaymentPortal({
    required String lockId,
    String? deviceInfo,
    String? studentSex,
  }) async {
    debugPrint('[PaymentService] getPaymentPortal for Lock: $lockId');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[PaymentService] No user logged in, aborting getPaymentPortal');
        throw 'You must be logged in to initialize payment.';
      }

      // Refresh token
      await user.getIdToken(true);

      final result = await _functions.httpsCallable('getPaymentPortal').call({
        'lockId': lockId,
        'deviceInfo': deviceInfo ?? 'Flutter App',
        'studentSex': studentSex,
      });

      if (result.data['status'] == 'SUCCESS') {
        return {
          'authorization_url': result.data['authorization_url'],
          'access_code': result.data['access_code'],
          'total_amount': (result.data['total_amount'] as num?)?.toDouble() ?? 0.0,
          'reference': result.data['reference'],
        };
      }
      
      final String message = result.data['message'] ?? 'Failed to initialize payment portal.';
      throw message;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] Portal failed: ${e.code} - ${e.message}');
      throw e.message ?? 'Could not initialize payment session.';
    } catch (e) {
      debugPrint('[PaymentService] Unexpected portal error: $e');
      throw 'Payment system is currently unavailable.';
    }
  }

  // ─── UNIFIED LAUNCHER ───────────────────────────────────────────────────────

  /// The new production-grade unified launcher.
  /// Handles the full lifecycle: Lock -> Init -> Redirect/WebView.
  Future<bool> startSecureBooking({
    required BuildContext context,
    required String hostelId,
    required String roomId,
    required String checkIn,
    required String checkOut,
    String? idempotencyKey,
    String? deviceInfo,
    String? studentSex,
  }) async {
    try {
      // 1. Prepare (Lock)
      final lockId = await prepareBooking(
        hostelId: hostelId,
        roomId: roomId,
        checkIn: checkIn,
        checkOut: checkOut,
        idempotencyKey: idempotencyKey,
      );

      if (!context.mounted) return false;

      // 2. Get Portal
      final portalData = await getPaymentPortal(
        lockId: lockId,
        deviceInfo: deviceInfo,
        studentSex: studentSex,
      );

      final String authUrl = portalData['authorization_url'];
      final String accessCode = portalData['access_code'] ?? '';
      final double amount = portalData['total_amount'];
      final String reference = portalData['reference'];

      if (!context.mounted) return false;

      // 3. Launch Secure Sheet (Handles Web Inline and Mobile WebView)
      final result = await PaymentSheet.show(
        context,
        authUrl: authUrl,
        accessCode: accessCode,
        reference: reference,
        bookingId: reference, // In v3, bookingId = reference
        amount: amount,
      );
      return result == true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Verify payment status with the backend.
  /// This is used for manual verification if the webhook is delayed.
  Future<bool> verifyAndSync(String reference, {String? bookingId}) async {
    debugPrint('[PaymentService] verifyAndSync for Ref: $reference');

    // 1. Ensure user is authenticated
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[PaymentService] Verify failed: User not logged in');
      return false;
    }

    try {
      // 2. Force token refresh to ensure backend has valid context
      debugPrint('[PaymentService] Refreshing auth token for verification...');
      await user.getIdToken(true);

      final result = await _functions.httpsCallable('verifyBooking').call({
        'reference': reference,
      });

      if (result.data['status'] == 'PAID') {
        debugPrint('[PaymentService] Payment Verified: Success');
        return true;
      }
      debugPrint('[PaymentService] Payment not yet verified: ${result.data['status']}');
      return false;
    } catch (e) {
      debugPrint('[PaymentService] Verification error: $e');
      return false;
    }
  }

  // ─── UTILITIES ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBanks() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.getBanks))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('[PaymentService] getBanks error: $e');
    }
    return [];
  }

  Future<String> createSubAccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required String percentage,
    required String email,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.createSubAccount),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'business_name': businessName,
        'settlement_bank': bankCode,
        'account_number': accountNumber,
        'percentage_charge': double.tryParse(percentage) ?? 0.0,
        'primary_contact_email': email,
      }),
    ).timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body);
    if (data['status'] == true) {
      return data['data']['subaccount_code'] as String;
    }
    throw data['message'] ?? 'Failed to create subaccount';
  }
}
