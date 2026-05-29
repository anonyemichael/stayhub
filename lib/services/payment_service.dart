import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:stayhub/core/api_config.dart';
import 'package:stayhub/services/firestore_service.dart';

class PaymentService {
  static final http.Client _client = http.Client();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

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
      await user.getIdToken(true);

      debugPrint('[PaymentService] Calling prepareBooking callable...');
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
      debugPrint('[PaymentService] Prepare failed: ${e.code} - ${e.message} details=${e.details}');
      throw e.message ?? 'Room is unavailable for these dates.';
    } catch (e) {
      debugPrint('[PaymentService] Unexpected prepare error: $e');
      if (e is String) rethrow;
      throw 'Could not start booking process. Please try again.';
    }
  }

  /// STEP 2: Get the payment portal URL using the lockId.
  Future<Map<String, dynamic>> getPaymentPortal({
    String? lockId,
    String? bookingId,
    String? deviceInfo,
    String? studentSex,
  }) async {
    debugPrint('[PaymentService] getPaymentPortal lockId=$lockId bookingId=$bookingId');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[PaymentService] No user logged in, aborting getPaymentPortal');
        throw 'You must be logged in to initialize payment.';
      }

      await user.getIdToken(true);

      final result = await _functions.httpsCallable('getPaymentPortal').call({
        'bookingId': bookingId,
      });

      if (result.data['status'] == 'SUCCESS') {
        return {
          'status': 'SUCCESS',
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
      if (e is String) rethrow;
      throw 'Payment system is currently unavailable.';
    }
  }

  // ─── UNIFIED LAUNCHER ───────────────────────────────────────────────────────

  /// Returns academic check-in/check-out dates for the given payment period.
  /// Reads from Firestore config/academicCalendar; falls back to computed dates.
  Future<Map<String, DateTime>> _getAcademicDates(String paymentPeriod) async {
    try {
      final configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('academicCalendar')
          .get();
      if (configDoc.exists) {
        final data = configDoc.data()!;
        final now = DateTime.now();
        String key;
        if (paymentPeriod == 'year') {
          key = 'year';
        } else {
          // semester1 = Aug–Dec, semester2 = Jan–Jul
          key = (now.month >= 8) ? 'semester1' : 'semester2';
        }
        final pd = data[key] as Map<String, dynamic>?;
        if (pd != null) {
          final start = (pd['start'] as Timestamp?)?.toDate();
          final end = (pd['end'] as Timestamp?)?.toDate();
          if (start != null && end != null) {
            return {'checkIn': start, 'checkOut': end};
          }
        }
      }
    } catch (_) {}

    // Fallback: compute from standard academic calendar
    final now = DateTime.now();
    final baseYear = (now.month >= 8) ? now.year : now.year - 1;
    if (paymentPeriod == 'year') {
      return {
        'checkIn': DateTime(baseYear, 9, 1),
        'checkOut': DateTime(baseYear + 1, 5, 31),
      };
    } else if (now.month >= 8) {
      return {
        'checkIn': DateTime(baseYear, 9, 1),
        'checkOut': DateTime(baseYear, 12, 31),
      };
    } else {
      return {
        'checkIn': DateTime(now.year, 1, 15),
        'checkOut': DateTime(now.year, 5, 31),
      };
    }
  }

  /// Creates a booking request for the agent to approve.
  /// Dates are derived from the academic calendar (Firestore config), not the device clock.
  Future<bool> requestBooking({
    required String hostelId,
    required String roomId,
    required String studentSex,
    required Map<String, dynamic> hostelData,
    String paymentPeriod = 'semester',
    String? roomTypeName,
    int? capacity,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw "Authentication required";

      final userName = user.displayName ?? "Student";
      final userEmail = user.email ?? "";
      final basePrice = double.tryParse(hostelData['price']?.toString() ?? '0') ?? 0.0;
      final serviceCharge = basePrice * 0.10;

      final String effectiveOwnerId =
          (hostelData['is_owner_property'] == true ? hostelData['agentId'] : hostelData['ownerId'])?.toString() ?? '';
      final String effectiveAgentId =
          (hostelData['is_owner_property'] == true ? null : hostelData['agentId'])?.toString() ?? '';

      final dates = await _getAcademicDates(paymentPeriod);

      final bookingData = {
        'userId': user.uid,
        'userName': userName,
        'userEmail': userEmail,
        'hostelId': hostelId,
        'hostelName': hostelData['name'],
        'hostelImage': hostelData['image'],
        'imageUrl': hostelData['image'],
        'location': hostelData['location'] ?? '',
        'roomId': roomId,
        'roomType': roomTypeName ?? (roomId == 'legacy' ? 'Standard Room' : roomId),
        'capacity': capacity,
        'paymentPeriod': paymentPeriod,
        'checkIn': dates['checkIn'],
        'checkOut': dates['checkOut'],
        'status': 'PENDING_APPROVAL',
        'studentSex': studentSex,
        'agentId': effectiveAgentId.isNotEmpty ? effectiveAgentId : hostelData['ownerId'] ?? '',
        'ownerId': effectiveOwnerId,
        'price': basePrice + serviceCharge,
        'amounts': {
          'base': basePrice,
          'serviceCharge': serviceCharge,
          'agentShare': serviceCharge * 0.5,
          'platformShare': serviceCharge * 0.5,
          'commission': serviceCharge,
          'total': basePrice + serviceCharge,
          'currency': 'GHS',
        },
        'hostelSnapshot': {
          'name': hostelData['name'],
          'address': hostelData['location'],
          'ownerId': effectiveOwnerId,
          'agentId': effectiveAgentId.isNotEmpty ? effectiveAgentId : null,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.addBooking(user.uid, bookingData);
      return true;
    } catch (e) {
      debugPrint('[PaymentService] requestBooking FAILED: $e');
      rethrow;
    }
  }


  /// Verify payment status with the backend.
  Future<bool> verifyAndSync(String reference, {String? bookingId}) async {
    debugPrint('[PaymentService] verifyAndSync for Ref: $reference');
    User? user = _auth.currentUser;
    for (int i = 0; i < 5 && user == null; i++) {
      await Future.delayed(const Duration(seconds: 1));
      user = _auth.currentUser;
    }
    if (user == null) {
      debugPrint('[PaymentService] Verify failed: no user after 5s wait');
      return false;
    }
    try {
      await user.getIdToken(true);
      final result = await _functions.httpsCallable('verifyBooking').call({
        'reference': reference,
      });
      final status = result.data['status'] as String? ?? '';
      debugPrint('[PaymentService] verifyAndSync result: $status');
      return status == 'PAID';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] verifyAndSync SDK error: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[PaymentService] verifyAndSync error: $e');
      return false;
    }
  }

  // ─── UTILITIES ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBanks({String country = 'ghana'}) async {
    try {
      final uri = Uri.parse(ApiConfig.getBanks).replace(queryParameters: {'country': country});
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
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

  /// Creates a Paystack subaccount for a hostel OWNER on behalf of the agent.
  /// Unlike [createSubAccount], this does NOT write to Firestore — it simply
  /// calls `createOwnerSubaccount` and returns the subaccount code so it can
  /// be stored on the hostel document. The agent's own payment profile is
  /// completely untouched.
  Future<({String subaccountCode, bool isVerified, String message})> createOwnerSubaccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Authentication required to create owner subaccount.';
      await user.getIdToken(true);

      final result = await _functions
          .httpsCallable('createOwnerSubaccount')
          .call({
        'business_name': businessName,
        'bank_code': bankCode,
        'account_number': accountNumber,
      });

      if (result.data['status'] == 'success') {
        return (
          subaccountCode: result.data['subaccount_code'] as String,
          isVerified: result.data['is_verified'] as bool? ?? false,
          message: result.data['message'] as String? ?? 'Owner payout account linked.',
        );
      }
      throw result.data['message'] ?? 'Failed to create owner subaccount';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] createOwnerSubaccount callable failed: ${e.code} ${e.message}');
      throw e.message ?? 'Owner subaccount creation failed';
    } catch (e) {
      debugPrint('[PaymentService] createOwnerSubaccount error: $e');
      if (e is String) rethrow;
      throw 'Could not create owner payout account. Please try again.';
    }
  }

  /// Creates a Paystack subaccount via the secure callable Cloud Function.
  /// Returns a record of (subaccountCode, isVerified).
  /// The function also deactivates the old subaccount and propagates the new
  /// code to any owner-type hostel documents this agent owns.
  Future<({String subaccountCode, bool isVerified, String message})> createSubAccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required String percentage,
    required String email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Authentication required to create subaccount.';
      await user.getIdToken(true);

      final result = await _functions
          .httpsCallable('createPaystackSubaccount')
          .call({
        'business_name': businessName,
        'bank_code': bankCode,
        'account_number': accountNumber,
        'role': 'agent',
      });

      if (result.data['status'] == 'success') {
        return (
          subaccountCode: result.data['subaccount_code'] as String,
          isVerified: result.data['is_verified'] as bool? ?? false,
          message: result.data['message'] as String? ?? 'Payment account linked.',
        );
      }
      throw result.data['message'] ?? 'Failed to create subaccount';
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] createSubAccount callable failed: ${e.code} ${e.message}');
      throw e.message ?? 'Subaccount creation failed';
    } catch (e) {
      debugPrint('[PaymentService] createSubAccount error: $e');
      if (e is String) rethrow;
      throw 'Could not create payout account. Please try again.';
    }
  }
}
