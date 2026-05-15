import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

// COMPLETE AND RESTORED FIRESTORE SERVICE

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- UNIQUE ID GENERATORS ---
  
  String generateBookingId() {
    final now = DateTime.now();
    final year = now.year.toString();
    // Use milliseconds + a random 4-digit suffix for global uniqueness
    final timeComponent = (now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final randomSuffix = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    return "BK-$year-$timeComponent$randomSuffix";
  }

  String generateTransactionRef() {
    return "TX-${DateTime.now().millisecondsSinceEpoch}";
  }

  // ===========================================================================
  // 1. USER & AGENT & ADMIN PROFILES
  // ===========================================================================

  Stream<DocumentSnapshot> getUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot> getAgentProfile(String uid) {
    return _db.collection('agents').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot> getAdminProfile(String email) {
    return _db.collection('admins').doc(email).snapshots();
  }

  // Config
  Future<Map<String, dynamic>> getAppConfig() async {
    final doc = await _db.collection('app_settings').doc('general').get();
    return doc.data() ?? {};
  }

  // Also aliased as getUserData in some places
  Stream<DocumentSnapshot> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateAgentProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('agents').doc(uid).set(data, SetOptions(merge: true));
  }

  // --- ADMIN MANAGEMENT ---
  
  Future<void> addAdmin(String email, String role, String addedBy) async {
    // We use Email as Document ID for easy lookup/invitation
    await _db.collection('admins').doc(email).set({
      'email': email,
      'role': role, // 'super_admin' or 'content_admin'
      'addedBy': addedBy,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeAdmin(String email) async {
    await _db.collection('admins').doc(email).delete();
  }

  Stream<DocumentSnapshot> getAdminRole(String email) {
    return _db.collection('admins').doc(email).snapshots();
  }

  // ===========================================================================
  // 2. HOSTELS
  // ===========================================================================

  Stream<QuerySnapshot> getHostels({int? limit}) {
    Query query = _db.collection('hostels');
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Stream<QuerySnapshot> getFeaturedHostels({int? limit}) {
    Query query = _db.collection('hostels').where('isFeatured', isEqualTo: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Stream<QuerySnapshot> getTrendingHostels({int? limit}) {
    Query query = _db.collection('hostels').orderBy('rating', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Stream<QuerySnapshot> getAgentHostels(String agentId) {
  return _db.collection('hostels')
      .where('agentId', isEqualTo: agentId)
      .snapshots();
}

  Future<String> addHostel(Map<String, dynamic> hostelData) async {
    final docRef = await _db.collection('hostels').add(hostelData);
    return docRef.id;
  }

  Future<void> updateHostel(String docId, Map<String, dynamic> data) async {
    await _db.collection('hostels').doc(docId).update(data);
  }

  Future<DocumentSnapshot?> findHostelByName(String name) async {
    // Try exact match first
    final exactQuery = await _db.collection('hostels').where('name', isEqualTo: name).limit(1).get();
    if (exactQuery.docs.isNotEmpty) return exactQuery.docs.first;

    // Try aggressive word match (fallback)
    final allHostels = await _db.collection('hostels').get();
    final searchWords = name.toLowerCase().split(' ').where((w) => w.length > 2).toList();
    
    for (var doc in allHostels.docs) {
      final hostelName = (doc.data()['name'] ?? "").toString().toLowerCase();
      // Case-insensitive exact or partial
      if (hostelName == name.toLowerCase() || hostelName.contains(name.toLowerCase())) {
        return doc;
      }
      // Word overlap
      for (var word in searchWords) {
        if (hostelName.contains(word)) return doc;
      }
    }
    return null;
  }

  // ===========================================================================
  // 3. CLIPS
  // ===========================================================================

  Stream<QuerySnapshot> getClips({int? limit}) {
    Query query = _db.collection('clips').orderBy('timestamp', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots();
  }

  Stream<DocumentSnapshot> getClip(String clipId) {
    return _db.collection('clips').doc(clipId).snapshots();
  }

  Future<void> toggleClipLike(String uid, String clipId, bool isLiked) async {
    final clipRef = _db.collection('clips').doc(clipId);
    if (isLiked) {
      await clipRef.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await clipRef.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  Future<void> deleteClip(String clipId) async {
    await _db.collection('clips').doc(clipId).delete();
  }

  Future<void> addClipComment(String uid, String clipId, String text, String userName, String? userPhoto) async {
    final batch = _db.batch();
    
    final commentRef = _db.collection('clips').doc(clipId).collection('comments').doc();
    batch.set(commentRef, {
      'uid': uid,
      'text': text,
      'userName': userName,
      'userPhoto': userPhoto,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final clipRef = _db.collection('clips').doc(clipId);
    batch.update(clipRef, {'commentCount': FieldValue.increment(1)});

    await batch.commit();
  }

  Stream<QuerySnapshot> getClipComments(String clipId) {
    return _db.collection('clips').doc(clipId).collection('comments').orderBy('timestamp', descending: true).snapshots();
  }

  // ===========================================================================
  // 4. SUPPORT & FAQS
  // ===========================================================================

  Stream<QuerySnapshot> getFaqs() {
    return _db.collection('faqs').snapshots();
  }

  // ===========================================================================
  // 5. BOOKINGS
  // ===========================================================================

  Stream<QuerySnapshot> getUserBookings(String uid) {
    return _db.collection('users').doc(uid).collection('bookings').orderBy('checkIn', descending: true).snapshots();
  }

  Future<void> addBooking(String uid, Map<String, dynamic> bookingData) async {
    final bookingId = generateBookingId();
    bookingData['bookingId'] = bookingId;
    bookingData['createdAt'] = FieldValue.serverTimestamp();
    
    // 1. Save to User's private bookings
    await _db.collection('users').doc(uid).collection('bookings').doc(bookingId).set(bookingData);
    
    // 2. Save to global 'bookings' collection for Admin/Traceability
    await _db.collection('bookings').doc(bookingId).set(bookingData);

    // 3. Notify the Agent
    final agentId = bookingData['agentId']?.toString();
    if (agentId != null && agentId.isNotEmpty) {
      await _db.collection('users').doc(agentId).collection('notifications').add({
        'title': 'New Booking Request! 🏠',
        'body': '${bookingData['userName']} has requested a room at ${bookingData['hostelName']}.',
        'type': 'BOOKING_REQUEST',
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }
  }

  // Used by Agents to Approve/Reject bookings
  /// Finds a booking by its payment reference
  Future<Map<String, dynamic>?> findBookingByReference(String reference) async {
    final snapshot = await _db.collection('bookings')
        .where('paymentReference', isEqualTo: reference)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      data['id'] = snapshot.docs.first.id;
      return data;
    }
    return null;
  }

  Future<void> updateBookingStatus(String userId, String bookingId, String status) async {
    final userBookingRef = _db.collection('users').doc(userId).collection('bookings').doc(bookingId);
    final globalBookingRef = _db.collection('bookings').doc(bookingId);
    
    await _db.runTransaction((transaction) async {
       final bookingSnapshot = await transaction.get(globalBookingRef);
       if (!bookingSnapshot.exists) return;

       transaction.set(userBookingRef, {'status': status, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
       transaction.set(globalBookingRef, {'status': status, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
       
       if (status == 'PAID') {
          final data = bookingSnapshot.data() as Map<String, dynamic>;
          final agentId = data['agentId'];
          final double agentEarnings = (data['agentPrice'] as num?)?.toDouble() ?? 0.0;
          
          if (agentId != null && agentEarnings > 0) {
             final agentRef = _db.collection('agents').doc(agentId);
             
             // 1. Increment Wallet
             transaction.update(agentRef, {
               'wallet_balance': FieldValue.increment(agentEarnings)
             });
             
             // 2. Add Transaction Record to Agent
             final agentTxnRef = _db.collection('agents').doc(agentId).collection('transactions').doc();
             transaction.set(agentTxnRef, {
               'amount': agentEarnings,
               'type': 'credit',
               'description': 'Commission: ${data['hostelName']} ($bookingId)',
               'date': FieldValue.serverTimestamp(),
               'bookingId': bookingId,
               'status': 'completed'
             });
          }
       }
    });
    
    // Create a notification for the user
    String notifTitle = "Booking Update";
    String notifBody = "Your booking ($bookingId) status is now: $status";
    
    if (status == 'CONFIRMED') {
      notifTitle = "Booking Approved! 🚀";
      notifBody = "Your booking for ${bookingId} is approved! Please make your payment now to secure your room.";
    } else if (status == 'PAID') {
      notifTitle = "Payment Confirmed! ✅";
      notifBody = "We've received your payment for $bookingId. Your stay is officially confirmed!";
    }

    await createNotification(userId, notifTitle, notifBody, type: 'booking');
  }

  Future<void> recordPayment({
    required String bookingId,
    required String userId,
    required String reference,
    required double amount,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    final txnId = reference; // Use Paystack reference as unique ID
    final txnData = {
      'transactionId': txnId,
      'bookingId': bookingId,
      'userId': userId,
      'reference': reference,
      'amount': amount,
      'status': status, // 'success', 'failed'
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata,
    };

    // 1. Save to global transactions for Admin
    await _db.collection('transactions').doc(txnId).set(txnData);

    // 2. Link to user
    await _db.collection('users').doc(userId).collection('transactions').doc(txnId).set(txnData);

    // 3. Update Booking Status and link reference if successful
    if (status == 'success') {
      await _db.collection('bookings').doc(bookingId).update({
        'status': 'PAID',
        'paymentReference': reference,
        'paidAt': FieldValue.serverTimestamp(),
      });
      await updateBookingStatus(userId, bookingId, 'PAID');
    }
  }

  // ===========================================================================
  // 5.5. ADMIN SETTINGS
  // ===========================================================================

  Future<double> getGlobalCommission() async {
    try {
      final doc = await _db.collection('settings').doc('commission').get();
      if (doc.exists) {
        // Returns percentage (e.g. 2.0 for 2%)
        return (doc.data()?['platform_fee_percent'] as num?)?.toDouble() ?? 2.0;
      }
    } catch (e) {
      debugPrint("Error fetching commission: $e");
    }
    return 2.0; // Default 2%
  }

  Future<void> setGlobalCommission(double amount) async {
    await _db.collection('settings').doc('commission').set({
      'platform_fee_percent': amount, // Storing fixed amount in legacy field name
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===========================================================================
  // 6. WALLET & PAYOUTS
  // ===========================================================================

  Stream<DocumentSnapshot> getWalletBalance(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<QuerySnapshot> getUserTransactions(String uid) {
    return _db.collection('users').doc(uid).collection('transactions').orderBy('date', descending: true).snapshots();
  }

  Future<void> requestPayout({
    required String uid, 
    required double amount, 
    required String bankName, 
    required String accountNumber,
    String? businessName,
  }) async {
    final agentRef = _db.collection('agents').doc(uid);
    final payoutRef = _db.collection('payouts').doc();
    final transactionRef = agentRef.collection('transactions').doc();

    await _db.runTransaction((transaction) async {
      final agentSnap = await transaction.get(agentRef);
      if (!agentSnap.exists) throw Exception("Agent profile not found");

      final data = agentSnap.data() as Map<String, dynamic>;
      final currentBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        throw Exception("Insufficient balance. Available: GHS $currentBalance");
      }

      // 1. Decrement Balance
      transaction.update(agentRef, {
        'wallet_balance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Create Payout Request
      transaction.set(payoutRef, {
        'agentId': uid,
        'amount': amount,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'businessName': businessName ?? data['business_name'] ?? "Unknown",
        'status': 'pending',
        'agentTransactionId': transactionRef.id, // Store ref for atomic completion
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Record Transaction (Debit)
      transaction.set(transactionRef, {
        'amount': amount,
        'type': 'debit',
        'description': 'Withdrawal Request: $bankName',
        'date': FieldValue.serverTimestamp(),
        'status': 'pending',
        'payoutId': payoutRef.id,
      });
    });
  }

  // ===========================================================================
  // 7. FAVORITES
  // ===========================================================================

  Future<void> toggleFavorite(String uid, String hostelId, bool isCurrentlyFavorite) async {
    final docRef = _db.collection('users').doc(uid);
    if (isCurrentlyFavorite) {
      await docRef.update({'favorites': FieldValue.arrayRemove([hostelId])});
    } else {
      await docRef.set({'favorites': FieldValue.arrayUnion([hostelId])}, SetOptions(merge: true));
    }
  }

  // ===========================================================================
  // 8. NOTIFICATIONS
  // ===========================================================================

  Stream<QuerySnapshot> getUserNotifications(String uid) {
    return _db.collection('users').doc(uid).collection('notifications').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> createNotification(String uid, String title, String body, {String type = 'general'}) async {
    await _db.collection('users').doc(uid).collection('notifications').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': type,
    });
  }

  Future<void> markNotificationAsRead(String uid, String notifId) async {
    await _db.collection('users').doc(uid).collection('notifications').doc(notifId).update({
      'isRead': true,
    });
  }

  Future<void> refundPayout({
    required String payoutId,
    required String agentId,
    required double amount,
    required String reason,
  }) async {
    final agentRef = _db.collection('agents').doc(agentId);
    final payoutRef = _db.collection('payouts').doc(payoutId);
    final transactionRef = agentRef.collection('transactions').doc();

    await _db.runTransaction((transaction) async {
      final payoutSnap = await transaction.get(payoutRef);
      if (!payoutSnap.exists) throw Exception("Payout record not found");
      
      final pData = payoutSnap.data() as Map<String, dynamic>;
      final txId = pData['agentTransactionId'];

      // 1. Increment Balance
      transaction.update(agentRef, {
        'wallet_balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Payout Status
      transaction.update(payoutRef, {
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Mark original withdrawal transaction as rejected
      if (txId != null) {
        final txRef = agentRef.collection('transactions').doc(txId);
        transaction.update(txRef, {
          'status': 'rejected',
          'description': 'Withdrawal Rejected: $reason',
        });
      }

      // 4. Record Transaction (Credit - Refund)
      transaction.set(transactionRef, {
        'amount': amount,
        'type': 'credit',
        'description': 'Refund: Withdrawal Rejected',
        'date': FieldValue.serverTimestamp(),
        'status': 'completed',
        'payoutId': payoutId,
      });

      // 5. Notify Agent
      final notifRef = _db.collection('users').doc(agentId).collection('notifications').doc();
      transaction.set(notifRef, {
        'title': 'Withdrawal Rejected ❌',
        'body': 'Your withdrawal request for GHS ${amount.toStringAsFixed(2)} was rejected: $reason. Funds have been returned to your wallet.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'PAYOUT_REJECTED',
        'payoutId': payoutId,
      });
    });
  }

  Future<void> completePayout(String payoutId) async {
    final payoutRef = _db.collection('payouts').doc(payoutId);
    
    await _db.runTransaction((transaction) async {
      final payoutSnap = await transaction.get(payoutRef);
      if (!payoutSnap.exists) throw Exception("Payout record not found");
      
      final pData = payoutSnap.data() as Map<String, dynamic>;
      final agentId = pData['agentId'];
      final amount = (pData['amount'] as num?)?.toDouble() ?? 0.0;
      final txId = pData['agentTransactionId'];

      // 1. Update Payout Status
      transaction.update(payoutRef, {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Transaction record in Agent's collection
      if (txId != null) {
        final txRef = _db.collection('agents').doc(agentId).collection('transactions').doc(txId);
        transaction.update(txRef, {
          'status': 'completed',
        });
      }

      // 3. Notify Agent
      final notifRef = _db.collection('users').doc(agentId).collection('notifications').doc();
      transaction.set(notifRef, {
        'title': 'Withdrawal Successful! ✅',
        'body': 'Your withdrawal of GHS ${amount.toStringAsFixed(2)} has been processed and sent to your account.',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'PAYOUT_COMPLETED',
        'payoutId': payoutId,
      });
    });
  }

  // ===========================================================================
  // 9. MUSIC
  // ===========================================================================

  Stream<QuerySnapshot> getMusic() {
    return _db.collection('music').orderBy('title').snapshots();
  }

  Future<void> seedMusic(List<Map<String, dynamic>> tracks) async {
    final batch = _db.batch();
    for (var track in tracks) {
      final docRef = _db.collection('music').doc(track['id']); // Use ID as doc name
      batch.set(docRef, track);
    }
    await batch.commit();
  }

  // ===========================================================================
  // 10. DATA SEEDER
  // ===========================================================================
  Future<void> ensureSampleDataExists() async {
    try {
      final hostels = await _db.collection('hostels').limit(1).get();

      if (hostels.docs.isEmpty) {
        debugPrint("✨ Seeding Database...");

        await _db.collection('admins').doc('placeholder_admin').set({
          'uid': 'REPLACE_WITH_REAL_UID',
          'email': 'admin@stayhub.com',
          'role': 'admin',
          'status': 'active'
        });
        debugPrint("✨ Database Seeded!");
      }
    } catch (e) {
      debugPrint("Error seeding database: $e");
    }
  }

  // ===========================================================================
  // 11. CASCADE DELETE (ADMIN ONLY)
  // ===========================================================================

  Future<void> deleteHostelCascade(String hostelId) async {
    final batch = _db.batch();
    int operationCount = 0;

    // 1. Delete Hostel Document
    final hostelRef = _db.collection('hostels').doc(hostelId);
    batch.delete(hostelRef);
    operationCount++;

    // 2. Delete Clips linked to this hostel
    final clipsQuery = await _db.collection('clips').where('hostelId', isEqualTo: hostelId).get();
    for (var doc in clipsQuery.docs) {
      if (operationCount < 450) {
        batch.delete(doc.reference);
        operationCount++;
      }
    }

    // 3. Delete Chats linked to this hostel (and messages)
    final chatsQuery = await _db.collection('chats').where('hostelId', isEqualTo: hostelId).get();
    for (var doc in chatsQuery.docs) {
      final messages = await doc.reference.collection('messages').get();
      for (var msg in messages.docs) {
        if (operationCount < 450) {
          batch.delete(msg.reference);
          operationCount++;
        }
      }
      if (operationCount < 450) {
        batch.delete(doc.reference);
        operationCount++;
      }
    }

    // 4. Delete Bookings (Collection Group)
    final bookingsQuery = await _db.collection('bookings').where('hostelId', isEqualTo: hostelId).get();
    for (var doc in bookingsQuery.docs) {
      final bookingId = doc.id;
      
      // 5. Delete associated Transactions (linked by bookingId)
      final txns = await _db.collection('transactions').where('bookingId', isEqualTo: bookingId).get();
      for (var t in txns.docs) {
        if (operationCount < 450) {
          batch.delete(t.reference);
          operationCount++;
        }
      }

      if (operationCount < 450) {
        batch.delete(doc.reference);
        operationCount++;
      }
    }

    // 6. Remove from User Favorites
    final usersWithFav = await _db.collection('users').where('favorites', arrayContains: hostelId).get();
    for (var doc in usersWithFav.docs) {
      if (operationCount < 450) {
        batch.update(doc.reference, {'favorites': FieldValue.arrayRemove([hostelId])});
        operationCount++;
      }
    }

    await batch.commit();
  }

  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    await _db.collection('users').doc(recipientId).collection('notifications').add({
      'title': "New message from $senderName",
      'body': messageText,
      'type': 'chat',
      'chatId': chatId,
      'senderId': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Stream<int> getTotalUnreadCount(String uid) {
    return _db.collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            total += (data['unreadCount_$uid'] as int? ?? 0);
          }
          return total;
        });
  }
}