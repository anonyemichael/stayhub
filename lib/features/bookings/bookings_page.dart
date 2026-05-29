import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // For Glassmorphism
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/bookings/booking_details_page.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:stayhub/features/bookings/receipt_page.dart';
import 'package:stayhub/services/payment_sheet.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final double platformFee;
  final String? roomType;
  final int? capacity;
  final String? paymentReference;
  final String? ownerSubaccountCode;
  final String? partnerType;
  final double basePrice;
  final double agentPrice;

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
    this.platformFee = 50.0, 
    this.roomType,
    this.capacity,
    this.paymentReference,
    this.ownerSubaccountCode,
    this.partnerType,
    this.basePrice = 0.0,
    this.agentPrice = 0.0,
    this.authorizationUrl,
    this.accessCode,
    this.hostelId,
    this.roomId,
  });

  final String? authorizationUrl;
  final String? accessCode;
  final String? hostelId;
  final String? roomId;

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
      roomType: data['roomType'],
      capacity: data['capacity'] is int ? data['capacity'] : (data['capacity'] != null ? int.tryParse(data['capacity'].toString()) : null),
      paymentReference: data['paymentReference'],
      ownerSubaccountCode: data['ownerSubaccountCode'],
      partnerType: data['partnerType'],
      basePrice: (data['amounts']?['base'] ?? data['basePrice'] as num?)?.toDouble() ?? 0.0,
      agentPrice: (data['amounts']?['commission'] != null 
        ? (data['amounts']['commission'] as num).toDouble() * 0.5 
        : (data['agentPrice'] as num?)?.toDouble() ?? 0.0),
      authorizationUrl: data['authorizationUrl'],
      accessCode: data['accessCode'],
      hostelId: data['hostelId'],
      roomId: data['roomId'],
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
  final Set<String> _pendingVerification = {};

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
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: user == null
                      ? Center(
                          child: Text("Please log in to view bookings",
                              style: TextStyle(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7))))
                      : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: StreamBuilder<QuerySnapshot>(
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

                      // AUTO-REFRESH: The StreamBuilder already keeps our list up to date.
                      // We removed the auto-push logic here to prevent race conditions 
                      // with the WebView on mobile. Success navigation is now handled 
                      // in the awaited button click.

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildSegmentedTab(isDark),
                          const SizedBox(height: 20),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                                children: [
                                  _buildBookingList(allBookings, 'Active', isDark),
                                  _buildBookingList(allBookings, 'History', isDark),
                                ],
                            ),
                          ),
                        ],
                      );

                        },
                      ),
                    ),
                  ),
                ),
              ],
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
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        labelColor: isDark ? Colors.black : Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [Tab(text: 'Active'), Tab(text: 'History')],
      ),
    );
  }

  Widget _buildBookingList(List<Booking> allBookings, String type, bool isDark) {
    final filtered = type == 'Active'
        ? allBookings.where((b) => b.status == 'PENDING' || b.status == 'CONFIRMED' || b.status == 'CHECKED_IN').toList()
        : allBookings.where((b) => b.status == 'PAID' || b.status == 'COMPLETED' || b.status == 'CANCELLED' || b.status == 'REJECTED').toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 80, color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $type bookings found", style: TextStyle(color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          // Desktop: Grid Layout
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500, // Max width of a ticket
              mainAxisExtent: 460, // ample height
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) => RepaintBoundary(child: TicketCard(
              booking: filtered[index], 
              pendingVerification: _pendingVerification, 
              onPendingStatusChange: (bookingId) => setState(() => _pendingVerification.add(bookingId)),
              onPendingStatusClear: (bookingId) => setState(() => _pendingVerification.remove(bookingId)),
            )),
          );
        }

        // Mobile: List Layout
        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: RepaintBoundary(child: TicketCard(
                  booking: filtered[index], 
                  pendingVerification: _pendingVerification, 
                  onPendingStatusChange: (bookingId) => setState(() => _pendingVerification.add(bookingId)),
                  onPendingStatusClear: (bookingId) => setState(() => _pendingVerification.remove(bookingId)),
                )),
              ),
            );
          },
        );
      }
    );
  }
}

class TicketCard extends StatefulWidget {
  final Booking booking;
  final Set<String> pendingVerification;
  final Function(String) onPendingStatusChange;
  final Function(String) onPendingStatusClear;

  const TicketCard({
    super.key, 
    required this.booking, 
    required this.pendingVerification,
    required this.onPendingStatusChange,
    required this.onPendingStatusClear,
  });

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  final PaymentService _paymentService = PaymentService();
  String? _agentSubaccountCode;
  bool _isFetchingAgent = false;

  @override
  void initState() {
    super.initState();
    // Pre-calculate/fetch as much as possible for atomic checkout
    if (widget.booking.agentId.isNotEmpty) {
      _preFetchAgentData();
    }
  }

  Future<void> _preFetchAgentData() async {
    if (_isFetchingAgent) return;
    setState(() => _isFetchingAgent = true);
    try {
      final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(widget.booking.agentId).get();
      if (agentDoc.exists && mounted) {
        setState(() {
          _agentSubaccountCode = agentDoc.data()?['paystack_subaccount_code'];
          _isFetchingAgent = false;
        });
        debugPrint('[StayHub] Pre-fetched agent subaccount: $_agentSubaccountCode');
      }
    } catch (e) {
      debugPrint('[StayHub] Error pre-fetching agent: $e');
      if (mounted) setState(() => _isFetchingAgent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.booking.status == 'CONFIRMED' || widget.booking.status == 'PAID';
    final isCheckedIn = widget.booking.status == 'CHECKED_IN';
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
                  imageUrl: widget.booking.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  errorWidget: (context, url, error) => Container(height: 180, color: isDark ? Colors.grey[800] : Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                ),
              ),
              Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), gradient: LinearGradient(colors: [Colors.black.withOpacity(0.6), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.center)))),
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isCheckedIn ? Colors.blue.withOpacity(0.6) : (isUpcoming ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
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
                            isCheckedIn ? "ACTIVE STAY" : widget.booking.status, // Display "ACTIVE STAY" instead of raw status
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
                      widget.booking.hostelName, 
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
                            widget.booking.location, 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13)
                          ),
                        )
                      ]
                    ),
                    if (widget.booking.roomType != null || widget.booking.capacity != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.meeting_room_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              (widget.booking.roomType?.replaceAll('-', ' ') ?? "${widget.booking.capacity ?? '?'} in a room"),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  children: [_buildDateColumn("Check In", widget.booking.checkIn, textColor), Icon(Icons.arrow_forward, color: isDark ? Colors.grey[600] : Colors.grey[300]), _buildDateColumn("Check Out", widget.booking.checkOut, textColor)],
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "GHS ${widget.booking.price.toStringAsFixed(0)}", 
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[200] : Colors.blue.shade900),
                            ),
                          )
                        ],
                      ),
                    ),
                     if (widget.booking.status == 'CONFIRMED')
                        widget.pendingVerification.contains(widget.booking.id)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ElevatedButton.icon(
                          onPressed: () async {
                             if (widget.pendingVerification.contains(widget.booking.id)) return;
                             widget.onPendingStatusChange(widget.booking.id);

                              debugPrint('[StayHub] Pay Now button clicked');
                              
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) {
                                debugPrint('[StayHub] No user logged in, showing prompt');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please log in to continue with payment")),
                                  );
                                }
                                return;
                              }

                              try {
                               // LEGAL PROTECTION DIALOG (Simplified)
                               final bool? agreed = await showDialog<bool>(
                                 context: context,
                                 builder: (ctx) => AlertDialog(
                                   title: const Text("Confirm Payment", style: TextStyle(fontWeight: FontWeight.bold)),
                                   content: const Text(
                                     "By proceeding, you confirm that you have verified this hostel and agree to our Terms of Service.\n\n"
                                     "Note: Payments are non-refundable via the app.",
                                   ),
                                   actions: [
                                     TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                     ElevatedButton(
                                       onPressed: () => Navigator.pop(ctx, true), 
                                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                                       child: const Text("Agree & Pay"),
                                     ),
                                   ],
                                 )
                               );

                               if (agreed != true) {
                                 debugPrint('[StayHub] User did not agree to terms or dialog dismissed');
                                 if (mounted) widget.onPendingStatusClear(widget.booking.id);
                                 return;
                               }

                               if (!mounted) return;
                               debugPrint('[StayHub] User agreed, starting payment prep');

                               final email = FirebaseAuth.instance.currentUser?.email ?? "student@stayhub.com";
                               final ref = "REF-${DateTime.now().millisecondsSinceEpoch}";

                               // Ensure we have the agent data (fall back to manual fetch if pre-fetch failed)
                               String? subAccountCode = _agentSubaccountCode;
                               if (subAccountCode == null && widget.booking.agentId.isNotEmpty) {
                                 debugPrint('[StayHub] Agent code missing, fetching manually...');
                                 final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(widget.booking.agentId).get();
                                 subAccountCode = agentDoc.data()?['paystack_subaccount_code'];
                               }

                               debugPrint('[StayHub] Proceeding to secure payment sheet with diagnostic logging...');

                               try {
                                 debugPrint("STEP 1: Calling prepareBooking via PaymentService");
                                   final String lockId = await _paymentService.prepareBooking(
                                     hostelId: widget.booking.hostelId ?? '',
                                     roomId: widget.booking.roomId ?? 'legacy',
                                     checkIn: widget.booking.checkIn.toIso8601String(),
                                     checkOut: widget.booking.checkOut.toIso8601String(),
                                     idempotencyKey: 'PAY-${widget.booking.id}-${DateTime.now().millisecondsSinceEpoch}',
                                   );

                                 debugPrint("STEP 2: Calling getPaymentPortal via PaymentService");
                                 final portal = await _paymentService.getPaymentPortal(
                                   lockId: lockId,
                                 );
                                 if (portal['status'] == 'SUCCESS') {
                                   final String authUrl = portal['authorization_url'];
                                   final String accessCode = portal['access_code'] ?? '';
                                   final String reference = portal['reference'];
                                   final double amount = (portal['total_amount'] as num).toDouble();

                                   print("STEP 3: Showing PaymentSheet");
                                   final success = await PaymentSheet.show(
                                     context,
                                     authUrl: authUrl,
                                     accessCode: accessCode,
                                     reference: reference,
                                     bookingId: widget.booking.id,
                                     amount: amount,
                                   );

                                   if (success == true && context.mounted) {
                                     Navigator.push(context, MaterialPageRoute(
                                       builder: (_) => ReceiptPage(
                                         booking: widget.booking, 
                                         transactionRef: reference,
                                       )
                                     ));
                                   }
                                 } else {
                                   throw "Portal error: ${portal['message'] ?? 'Unknown error'}";
                                 }
                               } catch (e) {
                                 print("PAYMENT FLOW FAILED AT: $e");
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text("Diagnostic Failure: $e"), backgroundColor: Colors.red),
                                   );
                                 }
                               }
                             } catch (e) {
                               debugPrint('[StayHub] Payment Error: $e');
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment failed: $e")));
                               }
                             } finally {
                               if (mounted) {
                                 widget.onPendingStatusClear(widget.booking.id);
                               }
                             }
                          },
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text("Pay Now"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
                        )
                    else if (widget.booking.status == 'PAID')
                      ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptPage(booking: widget.booking, transactionRef: widget.booking.paymentReference ?? "N/A"))),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5),
                        child: const Text("View Receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    else if (widget.booking.status == 'CHECKED_IN')
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
                if (widget.booking.agentId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _messageAgent(context, widget.booking.agentId, widget.booking.hostelName),
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

  void _messageAgent(BuildContext context, String agentId, String hostelName) async {
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
      final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(agentId).get();
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
        'hostelName': hostelName,
        'studentName': currentUser.displayName ?? 'Student',
        'hostelId': hostelName, 
      });
      chatId = newChat.id;
    } else {
       await chatsRef.doc(chatId).set({
         'hostelName': hostelName, 
         'studentName': currentUser.displayName ?? 'Student',
       }, SetOptions(merge: true));
    }

    if (context.mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => 
         ChatPage(chatId: chatId!, otherUserId: agentId, otherUserName: hostelName) 
       ));
    }
  }
}
