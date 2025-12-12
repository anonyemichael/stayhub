import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Also aliased as getUserData in some places
  Stream<DocumentSnapshot> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // ===========================================================================
  // 2. HOSTELS
  // ===========================================================================

  Stream<QuerySnapshot> getHostels() {
    return _db.collection('hostels').orderBy('rating', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getFeaturedHostels() {
    return _db.collection('hostels').where('isFeatured', isEqualTo: true).snapshots();
  }

  Stream<QuerySnapshot> getAgentHostels(String agentId) {
    return _db.collection('hostels').where('agentId', isEqualTo: agentId).snapshots();
  }

  Future<void> addHostel(Map<String, dynamic> hostelData) async {
    await _db.collection('hostels').add(hostelData);
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
    await _db.collection('users').doc(uid).collection('bookings').add(bookingData);
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
  // 9. DATA SEEDER
  // ===========================================================================
  Future<void> ensureSampleDataExists() async {
    try {
      final hostels = await _db.collection('hostels').limit(1).get();

      if (hostels.docs.isEmpty) {
        print("✨ Seeding Database...");

        await _db.collection('admins').doc('placeholder_admin').set({
          'uid': 'REPLACE_WITH_REAL_UID',
          'email': 'admin@stayhub.com',
          'role': 'admin',
          'status': 'active'
        });
        print("✨ Database Seeded!");
      }
    } catch (e) {
      print("Error seeding database: $e");
    }
  }
}