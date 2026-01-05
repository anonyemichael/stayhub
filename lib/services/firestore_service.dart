import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// COMPLETE AND RESTORED FIRESTORE SERVICE

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===========================================================================
  // 1. USER & AGENT & ADMIN PROFILES
  // ===========================================================================

  Stream<DocumentSnapshot> getUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot> getAgentProfile(String uid) {
    return _db.collection('agents').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot> getAdminProfile(String uid) {
    return _db.collection('admins').doc(uid).snapshots();
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

  Stream<QuerySnapshot> getHostels() {
    return _db.collection('hostels').snapshots();
  }

  Stream<QuerySnapshot> getFeaturedHostels() {
    return _db.collection('hostels').where('isFeatured', isEqualTo: true).snapshots();
  }

  Stream<QuerySnapshot> getAgentHostels(String agentId) {
  return _db.collection('hostels')
      .where('agentId', isEqualTo: agentId)
      .snapshots();
}

  Future<void> addHostel(Map<String, dynamic> hostelData) async {
    await _db.collection('hostels').add(hostelData);
  }

  Future<void> updateHostel(String docId, Map<String, dynamic> data) async {
    await _db.collection('hostels').doc(docId).update(data);
  }

  Future<DocumentSnapshot?> findHostelByName(String name) async {
    final query = await _db.collection('hostels').where('name', isEqualTo: name).limit(1).get();
    if (query.docs.isNotEmpty) return query.docs.first;
    return null;
  }

  // ===========================================================================
  // 3. CLIPS
  // ===========================================================================

  Stream<QuerySnapshot> getClips() {
    return _db.collection('clips').snapshots();
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
    await _db.collection('clips').doc(clipId).collection('comments').add({
      'uid': uid,
      'text': text,
      'userName': userName,
      'userPhoto': userPhoto,
      'timestamp': FieldValue.serverTimestamp(),
    });
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
    final bookingRef = await _db.collection('users').doc(uid).collection('bookings').add(bookingData);
    
    // Notify Agent
    final agentId = bookingData['agentId'];
    if (agentId != null) {
      await createNotification(
        agentId, 
        "New Booking Request! 🏠", 
        "You have a new booking for ${bookingData['hostelName'] ?? 'a property'}. Check Bookings to verify."
      );
    }
    
    // Notify Admin (Optional, for oversight)
    // await createNotification('admin_uid', "New Booking", "User $uid booked ${bookingData['hostelName']}");
  }

  // Used by Agents to Approve/Reject bookings
  Future<void> updateBookingStatus(String userId, String bookingId, String status) async {
    final bookingRef = _db.collection('users').doc(userId).collection('bookings').doc(bookingId);
    
    await _db.runTransaction((transaction) async {
       final bookingSnapshot = await transaction.get(bookingRef);
       if (!bookingSnapshot.exists) return;

       transaction.update(bookingRef, {'status': status});
       
       // Handle Commission / Payout only when PAID
       // Fixed Logic: Wallet increments only when Student actually pays.
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
             
             // 2. Add Transaction Record
             final pendingTxnRef = _db.collection('agents').doc(agentId).collection('transactions').doc();
             transaction.set(pendingTxnRef, {
               'amount': agentEarnings,
               'type': 'credit',
               'description': 'Booking Revenue: ${data['hostelName']}',
               'date': FieldValue.serverTimestamp(),
               'bookingId': bookingId,
             });
          }
       }
    });
    
    // Create a notification for the user
    String notifBody = "Your booking was updated to: $status";
    if (status == 'CONFIRMED') notifBody = "Your booking has been APPROVED! You can now proceed to payment.";
    if (status == 'PAID') notifBody = "Payment received! Your booking is confirmed.";

    await createNotification(userId, "Booking Update", notifBody);
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

  Future<void> requestPayout(String uid, double amount, String method, String details) async {
    await _db.collection('payouts').add({
      'agentId': uid,
      'amount': amount,
      'method': method,
      'details': details,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
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

  Future<void> createNotification(String uid, String title, String body) async {
    await _db.collection('users').doc(uid).collection('notifications').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Future<void> markNotificationAsRead(String uid, String notificationId) async {
    await _db.collection('users').doc(uid).collection('notifications').doc(notificationId).update({'isRead': true});
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
}