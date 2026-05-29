import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/notification_service.dart';

class AgentBookingsPage extends StatefulWidget {
  const AgentBookingsPage({super.key});

  @override
  State<AgentBookingsPage> createState() => _AgentBookingsPageState();
}

class _AgentBookingsPageState extends State<AgentBookingsPage> {
  final _auth = FirebaseAuth.instance;
  String _activeFilter = 'PENDING';

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Authentication required."));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where(
              Filter.or(
                Filter('agentId', isEqualTo: user.uid),
                Filter('ownerId', isEqualTo: user.uid),
                Filter('hostelSnapshot.agentId', isEqualTo: user.uid),
                Filter('hostelSnapshot.ownerId', isEqualTo: user.uid),
              ),
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildErrorState(snapshot.error.toString(), isDark);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allDocs = snapshot.data!.docs;
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == _activeFilter;
          }).toList();

          final pendingCount = allDocs.where((d) => (d.data() as Map)['status'] == 'PENDING').length;
          final approvedCount = allDocs.where((d) => (d.data() as Map)['status'] == 'CONFIRMED').length;
          final paidCount = allDocs.where((d) => (d.data() as Map)['status'] == 'PAID').length;
          
          double earningsRaw = 0.0;
          for (var d in allDocs) {
            final data = d.data() as Map<String, dynamic>;
            if (data['status'] == 'PAID' || data['status'] == 'COMPLETED') {
              final amounts = data['amounts'] as Map<String, dynamic>?;
              if (amounts != null) {
                final base = (amounts['base'] as num? ?? 0.0).toDouble();
                final totalComm = (amounts['commission'] as num? ?? 0.0).toDouble();

                final isAgent = (data['agentId'] ?? data['hostelSnapshot']?['agentId']) == user.uid;
                final isOwner = (data['ownerId'] ?? data['hostelSnapshot']?['ownerId']) == user.uid;

                if (isAgent) earningsRaw += totalComm * 0.5;
                if (isOwner) earningsRaw += base;
              } else {
                // Legacy fallback
                earningsRaw += (data['agentPrice'] as num? ?? 0.0).toDouble();
              }
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 110)),

              // 2. STATS (Responsive Grid)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _buildStatBox("PENDING", pendingCount.toString(), Colors.orange),
                          _buildStatBox("CONFIRMED", approvedCount.toString(), Colors.green),
                          _buildStatBox("PAID", paidCount.toString(), const Color(0xFF10B981)),
                          _buildStatBox("REVENUE", "₵${earningsRaw.toStringAsFixed(0)}", Colors.blueAccent),
                        ],
                      );
                    }
                  ),
                ),
              ),

              // 3. FILTERS (Glass Tabs)
              SliverToBoxAdapter(
                child: Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: ['PENDING', 'CONFIRMED', 'PAID', 'REJECTED', 'COMPLETED'].map((filter) {
                      final isSelected = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                            ),
                            child: Center(
                              child: Text(
                                filter, 
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[500], 
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 11
                                )
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. LISTING
              if (filteredDocs.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(isDark))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        return _buildCleanBookingCard(context, data, filteredDocs[index].id, isDark);
                      },
                      childCount: filteredDocs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
  }

  Widget _buildCleanBookingCard(BuildContext context, Map<String, dynamic> data, String id, bool isDark) {
    final status = data['status'] ?? 'PENDING';
    final bookingId = data['bookingId'] ?? id;
    final studentId = data['userId'];
    final date = (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final statusColor = status == 'PENDING' ? Colors.orange : (status == 'CONFIRMED' ? Colors.green : (status == 'PAID' ? const Color(0xFF10B981) : (status == 'COMPLETED' ? Colors.blue : Colors.red)));
    
    // Fix Floating Point Error
    final rawPrice = data['price']?.toString() ?? '0';
    final formattedPrice = double.tryParse(rawPrice.replaceAll(',', ''))?.toStringAsFixed(0) ?? '0';
    
    // Clean Room Type Display - Ultimate Robustness
    final rawType = data['roomType'] ?? data['type'] ?? 'Standard';
    final capNum = data['capacity'];
    final capStr = capNum?.toString() ?? '?';
    
    // Convert '1-in-a-room' to '1 in a room'
    String roomDisplay = rawType.replaceAll('-', ' ');
    
    // If it's a specific grouping like '2 in a room', use it exactly
    if (roomDisplay.toLowerCase().contains('in a room')) {
       // Already specific
    } else if (capNum != null && capNum != 0) {
       // Add the capacity to the type
       roomDisplay = "$roomDisplay ($capStr in a room)";
    } else if (roomDisplay == 'Standard' || roomDisplay == 'Room') {
       // Total fallback
       roomDisplay = "$capStr in a room";
    }
    
    // Clean up any double-labeling just in case
    roomDisplay = roomDisplay.replaceFirst('(Standard)', '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(width: 12),
                Text("#$bookingId", style: TextStyle(color: statusColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(DateFormat('MMM dd, yyyy').format(date), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Price - Vertical Stack if squashed
                Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['userName'] ?? 'Student', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.1)),
                            const SizedBox(height: 6),
                            Text(data['hostelName'] ?? 'Hostel', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text("₵$formattedPrice", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                   ],
                ),
                
                const SizedBox(height: 24),
                
                // Badges
                Row(
                  children: [
                    _buildTag(Icons.hotel_outlined, roomDisplay),
                    const SizedBox(width: 10),
                    _buildTag(data['studentSex'] == 'Male' ? Icons.male : Icons.female, data['studentSex'] ?? 'Any'),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Dynamic Actions
                if (status == 'PENDING')
                  Row(
                    children: [
                      Expanded(child: _buildButton("DECLINE", Colors.red, true, () => _updateStatus(studentId, id, 'REJECTED'))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildButton("APPROVE", Colors.green, false, () => _updateStatus(studentId, id, 'CONFIRMED'))),
                    ],
                  ),
                  
                if (status == 'PAID')
                   Column(
                     children: [
                       _buildButton("MESSAGE STUDENT", const Color(0xFF2563EB), false, () => _openChat(context, studentId, data)),
                       const SizedBox(height: 12),
                       _buildButton("MARK COMPLETED", Colors.green, true, () => _updateStatus(studentId, bookingId, 'COMPLETED')),
                     ],
                   ),
                   
                if (status == 'CONFIRMED')
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                     child: const Center(child: Text("WAITING FOR PAYMENT", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w900))),
                   ),
                
                if (status == 'COMPLETED')
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                     child: const Center(child: Text("BOOKING COMPLETED", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w900))),
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, bool outlined, VoidCallback onTap) {
    return Material(
      color: outlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: outlined ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: outlined ? color : Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String userId, String bookingId, String status) async {
    await FirestoreService().updateBookingStatus(userId, bookingId, status);
    if (status == 'CONFIRMED') {
      await NotificationService().showNotification(title: "Booking Approved", body: "Pending student payment.");
    }
  }

  Future<void> _openChat(BuildContext context, String studentId, Map<String, dynamic> data) async {
    final agentId = _auth.currentUser?.uid;
    if (agentId == null) return;
    final chatsRef = FirebaseFirestore.instance.collection('chats');
    final query = await chatsRef.where('users', arrayContains: agentId).get();
    String? chatId;
    for (var doc in query.docs) {
      if (List<String>.from(doc['users']).contains(studentId)) {
        chatId = doc.id; break;
      }
    }
    if (chatId == null) {
      final newChat = await chatsRef.add({
        'users': [agentId, studentId],
        'lastMessage': '', 'lastMessageTime': FieldValue.serverTimestamp(),
        'hostelName': data['hostelName'], 'studentName': data['userName']
      });
      chatId = newChat.id;
    }
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(chatId: chatId!, otherUserName: data['userName'], otherUserId: studentId)));
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, size: 48, color: Colors.blueAccent),
          ),
          const SizedBox(height: 24),
          const Text("No bookings yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text("Your property listings will appear here once students start booking.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text("System Sync Required", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'monospace')),
            if (error.contains('index'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text("Please click the link in your debug console to enable this index.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
