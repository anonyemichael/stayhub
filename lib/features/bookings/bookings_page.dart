import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // For Glassmorphism
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/bookings/booking_details_page.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:stayhub/features/chat/chat_page.dart';

// 1. DATA MODEL
class Booking {
  final String id;
  final String hostelName;
  final String location;
  final String imageUrl;
  final DateTime checkIn;
  final DateTime checkOut;
  final String status; // 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'PAID'
  final double price;
  final String agentId;
  final double platformFee; // New: For fixed commission logic

  Booking({
    required this.id,
    required this.hostelName,
    required this.location,
    required this.imageUrl,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.price,
    required this.agentId,
    this.platformFee = 50.0, // Default fallback
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      hostelName: data['hostelName'] ?? 'Unknown Hostel',
      location: data['location'] ?? 'Unknown Location',
      imageUrl: data['imageUrl'] ?? 'https://picsum.photos/200',
      checkIn: (data['checkIn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      checkOut: (data['checkOut'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'CONFIRMED',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      agentId: data['agentId'] ?? '',
      platformFee: (data['platformFee'] as num?)?.toDouble() ?? 50.0,
    );
  }
}

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('My Bookings', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [Colors.blue.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: user == null
                ? Center(
                    child: Text("Please log in to view bookings",
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7))))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestoreService.getUserBookings(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: theme.primaryColor));
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      final allBookings = docs.map((doc) => Booking.fromFirestore(doc)).toList();

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildSegmentedTab(isDark),
                          const SizedBox(height: 20),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildBookingList(allBookings, 'Upcoming', isDark),
                                _buildBookingList(allBookings, 'Past', isDark),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTab(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        labelColor: isDark ? Colors.black : Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [Tab(text: 'Upcoming'), Tab(text: 'History')],
      ),
    );
  }

  Widget _buildBookingList(List<Booking> allBookings, String type, bool isDark) {
    final filtered = type == 'Upcoming'
        ? allBookings.where((b) => b.status == 'CONFIRMED' || b.status == 'PAID' || b.status == 'CHECKED_IN').toList()
        : allBookings.where((b) => b.status == 'COMPLETED' || b.status == 'CANCELLED').toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 80, color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $type bookings found", style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return TicketCard(booking: filtered[index]);
      },
    );
  }
}

class TicketCard extends StatelessWidget {
  final Booking booking;

  const TicketCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final isUpcoming = booking.status == 'CONFIRMED' || booking.status == 'PAID';
    final isCheckedIn = booking.status == 'CHECKED_IN';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: booking.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  errorWidget: (context, url, error) => Container(height: 150, color: isDark ? Colors.grey[800] : Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                ),
              ),
              Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center)))),
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isCheckedIn ? Colors.blue.withValues(alpha: 0.6) : (isUpcoming ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCheckedIn ? Icons.verified : (isUpcoming ? Icons.check_circle : Icons.history), 
                            color: Colors.white, 
                            size: 14
                          ), 
                          const SizedBox(width: 6), 
                          Text(
                            isCheckedIn ? "ACTIVE STAY" : booking.status, // Display "ACTIVE STAY" instead of raw status
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16, // Constrain width
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.hostelName, 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 22, 
                        fontWeight: FontWeight.bold, 
                        shadows: [Shadow(color: Colors.black54, blurRadius: 10)]
                      )
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14), 
                        const SizedBox(width: 4), 
                        Expanded(
                          child: Text(
                            booking.location, 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13)
                          ),
                        )
                      ]
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDateColumn("Check In", booking.checkIn, textColor), Icon(Icons.arrow_forward, color: isDark ? Colors.grey[600] : Colors.grey[300]), _buildDateColumn("Check Out", booking.checkOut, textColor)],
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Price", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            "GHS ${booking.price.toStringAsFixed(0)}", 
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[200] : Colors.blue.shade900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                    ),
                    if (booking.status == 'CONFIRMED')
                       ElevatedButton.icon(
                        onPressed: () async {
                           final email = FirebaseAuth.instance.currentUser?.email ?? "student@stayhub.com";
                           final ref = "REF-${DateTime.now().millisecondsSinceEpoch}";
                           
                           // Check for Agent Subaccount (Split Payment)
                           String? subAccountCode;
                           if (booking.agentId.isNotEmpty) {
                             try {
                               final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(booking.agentId).get();
                               if (agentDoc.exists) {
                                 subAccountCode = agentDoc.data()?['paystack_subaccount_code'];
                               }
                             } catch (e) {
                               debugPrint("Error fetching agent subaccount: $e");
                             }
                           }

                           String? reference;
                           if (subAccountCode != null && subAccountCode.isNotEmpty) {
                              // USE SPLIT PAYMENT with Fixed Commission
                              reference = await PaymentService().chargeCardWithSplit(
                                context: context, 
                                amount: booking.price, 
                                email: email, 
                                reference: ref,
                                subAccountCode: subAccountCode,
                                transactionCharge: booking.platformFee, // Passed here
                              );
                           } else {
                              // USE STANDARD PAYMENT (Platform keeps all)
                              reference = await PaymentService().chargeCard(
                                context: context, 
                                amount: booking.price, 
                                email: email, 
                                reference: ref
                              );
                           }

                           if (reference != null) {
                             // Success!
                             await FirestoreService().updateBookingStatus(
                               FirebaseAuth.instance.currentUser!.uid, 
                               booking.id, 
                               'PAID'
                             );
                             
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful! Booking Confirmed."), backgroundColor: Colors.green));
                             }
                           } else {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Cancelled"), backgroundColor: Colors.red));
                             }
                           }
                        },
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text("Pay Now"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
                      )
                    else if (booking.status == 'PAID')
                      ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsPage(booking: booking))),
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
                        child: const Text("View Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    else if (booking.status == 'CHECKED_IN')
                      ElevatedButton.icon(
                        onPressed: () {}, // No action needed or maybe show "Room Details"
                        icon: const Icon(Icons.home, size: 16),
                        label: const Text("My Room"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
                      )
                    else
                      OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text("Book Again", style: TextStyle(color: textColor))),
                  ],
                ),
                if (booking.agentId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _messageAgent(context, booking.agentId),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18), 
                      label: Text("Message Agent", style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateColumn(String label, DateTime date, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("${date.day} ${_getMonth(date.month)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        Text(date.year.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  String _getMonth(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  void _messageAgent(BuildContext context, String agentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check if chat exists
    final chatsRef = FirebaseFirestore.instance.collection('chats');
    final query = await chatsRef
        .where('users', arrayContains: currentUser.uid)
        .get();

    String? chatId;
    for (var doc in query.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(agentId)) {
        chatId = doc.id;
        break;
      }
    }

    // Get Agent Name
    String agentName = "Agent";
    try {
      final agentDoc = await FirebaseFirestore.instance.collection('users').doc(agentId).get();
      if (agentDoc.exists) {
        agentName = agentDoc['name'] ?? "Agent";
      }
    } catch (e) {
      debugPrint("Error fetching agent name: $e");
    }

    // Create if not exists
    if (chatId == null) {
      final newChat = await chatsRef.add({
        'users': [currentUser.uid, agentId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hostelName': booking.hostelName,
        'studentName': currentUser.displayName ?? 'Student',
        'hostelId': booking.hostelName, 
      });
      chatId = newChat.id;
    } else {
       await chatsRef.doc(chatId).set({
         'hostelName': booking.hostelName, 
         'studentName': currentUser.displayName ?? 'Student',
       }, SetOptions(merge: true));
    }

    if (context.mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => 
         ChatPage(chatId: chatId!, otherUserId: agentId, otherUserName: booking.hostelName) 
       ));
    }
  }
}
